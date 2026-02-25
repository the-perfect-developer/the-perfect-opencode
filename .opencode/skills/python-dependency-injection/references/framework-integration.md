# Framework Integration Guide

## Table of Contents
1. [FastAPI](#fastapi)
2. [Flask](#flask)
3. [Django](#django)

---

## FastAPI

FastAPI has **built-in DI** via `Depends()`. Use it for route-level dependencies and combine it with `dependency-injector` for app-level container management.

### Native Depends() Pattern

```python
from fastapi import FastAPI, Depends
from sqlalchemy.ext.asyncio import AsyncSession

app = FastAPI()

# Dependency provider function
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session  # yield enables teardown after request

# Route uses injected dependency
@app.get("/items")
async def read_items(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Item))
    return result.scalars().all()
```

### Authentication Dependency

Centralize auth logic as a reusable dependency:

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    user = await verify_token(token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    return user

@app.get("/profile")
async def get_profile(user: User = Depends(get_current_user)):
    return {"username": user.username}
```

### Combining with `dependency-injector`

Wire the container once at startup; use `@inject` in route handlers:

```python
# containers.py
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()
    db = providers.Resource(DatabaseResource, url=config.db_url)
    user_service = providers.Factory(UserService, db=db)

# main.py
from dependency_injector.wiring import inject, Provide
from fastapi import FastAPI
from containers import Container

app = FastAPI()
container = Container()

@app.on_event("startup")
async def startup():
    container.config.from_yaml("config.yaml")
    await container.init_resources()
    container.wire(packages=["myapp.routes"])

@app.on_event("shutdown")
async def shutdown():
    await container.shutdown_resources()

# routes/users.py
@router.post("/users")
@inject
async def create_user(
    data: UserCreate,
    service: UserService = Provide[Container.user_service],
):
    return await service.create(data)
```

### Testing FastAPI Routes

```python
# tests/test_routes.py
from fastapi.testclient import TestClient
from main import app
from containers import Container

def test_create_user():
    container = Container()
    container.user_service.override(FakeUserService())

    client = TestClient(app)
    response = client.post("/users", json={"name": "Alice"})
    assert response.status_code == 201
```

---

## Flask

Flask has no built-in DI. Integrate `dependency-injector` via the wiring mechanism.

### Setup

```bash
pip install "dependency-injector[flask]"
```

### Basic Integration

```python
# services.py
class GreetingService:
    def greet(self, name: str) -> str:
        return f"Hello, {name}!"

# containers.py
from dependency_injector import containers, providers
from services import GreetingService

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()
    greeting_service = providers.Factory(GreetingService)

# app.py
from flask import Flask, request, jsonify
from dependency_injector.wiring import inject, Provide
from containers import Container

def create_app() -> Flask:
    app = Flask(__name__)
    container = Container()
    container.config.from_yaml("config.yaml")
    container.wire(modules=["app.views"])  # wire after registering blueprints
    app.container = container
    return app

# views.py
from flask import Blueprint, request
from dependency_injector.wiring import inject, Provide
from containers import Container
from services import GreetingService

bp = Blueprint("greet", __name__)

@bp.route("/greet")
@inject
def greet(
    greeting_service: GreetingService = Provide[Container.greeting_service],
):
    name = request.args.get("name", "World")
    return {"message": greeting_service.greet(name)}
```

### Application Factory Pattern

```python
# factory.py
from flask import Flask
from containers import Container

def create_app(config: dict | None = None) -> Flask:
    app = Flask(__name__)

    container = Container()
    if config:
        container.config.from_dict(config)
    else:
        container.config.from_yaml("config.yaml")

    container.wire(packages=["myapp"])
    app.container = container

    from myapp.views import bp
    app.register_blueprint(bp)

    return app
```

### Testing Flask Routes

```python
# conftest.py
import pytest
from factory import create_app

@pytest.fixture
def app():
    return create_app({"db_url": "sqlite:///:memory:", "debug": True})

@pytest.fixture
def client(app):
    return app.test_client()

# test_views.py
def test_greet(client, app):
    from services import GreetingService
    from unittest.mock import MagicMock

    mock_service = MagicMock(spec=GreetingService)
    mock_service.greet.return_value = "Hello, Test!"

    with app.container.greeting_service.override(mock_service):
        response = client.get("/greet?name=Test")
        assert response.json["message"] == "Hello, Test!"
```

---

## Django

Django has no built-in DI but supports integration via `AppConfig.ready()`.

### Setup

```bash
pip install dependency-injector
```

### Project Structure

```
myproject/
├── myapp/
│   ├── apps.py
│   ├── containers.py
│   ├── services.py
│   └── views.py
└── myproject/
    ├── settings.py
    └── urls.py
```

### Service and Container

```python
# myapp/services.py
class OrderService:
    def __init__(self, db, cache):
        self.db = db
        self.cache = cache

    def get_order(self, order_id: int):
        cached = self.cache.get(f"order:{order_id}")
        if cached:
            return cached
        return self.db.query(Order).get(order_id)

# myapp/containers.py
from dependency_injector import containers, providers
from myapp.services import OrderService

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    db = providers.Singleton(Database, url=config.db_url)
    cache = providers.Singleton(RedisCache, host=config.redis_host)

    order_service = providers.Factory(
        OrderService,
        db=db,
        cache=cache,
    )
```

### Wire in AppConfig

Wire the container when Django starts up:

```python
# myapp/apps.py
from django.apps import AppConfig

class MyAppConfig(AppConfig):
    name = "myapp"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self):
        from myapp.containers import Container
        from django.conf import settings

        container = Container()
        container.config.from_dict({
            "db_url": settings.DATABASES["default"]["NAME"],
            "redis_host": settings.REDIS_HOST,
        })
        container.wire(modules=["myapp.views"])

        # Store on app for testing
        self.container = container
```

Register in `settings.py`:

```python
INSTALLED_APPS = [
    "myapp.apps.MyAppConfig",
    # ...
]
```

### Class-Based Views

```python
# myapp/views.py
from django.http import JsonResponse
from dependency_injector.wiring import inject, Provide
from myapp.containers import Container
from myapp.services import OrderService

@inject
def order_detail(
    request,
    order_id: int,
    service: OrderService = Provide[Container.order_service],
):
    order = service.get_order(order_id)
    return JsonResponse({"id": order.id, "status": order.status})
```

### Testing Django Views

```python
# tests/test_views.py
from django.test import TestCase, RequestFactory
from unittest.mock import MagicMock
from myapp.views import order_detail
from myapp.apps import MyAppConfig

class OrderViewTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.container = MyAppConfig("myapp", myapp).container

    def test_order_detail(self):
        mock_service = MagicMock()
        mock_service.get_order.return_value = Order(id=1, status="pending")

        with self.container.order_service.override(mock_service):
            request = self.factory.get("/orders/1/")
            response = order_detail(request, order_id=1)

        self.assertEqual(response.status_code, 200)
        mock_service.get_order.assert_called_with(1)
```

### Django Middleware Integration

Inject dependencies into middleware:

```python
# myapp/middleware.py
from dependency_injector.wiring import inject, Provide
from myapp.containers import Container
from myapp.services import AuditService

class AuditMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    @inject
    def __call__(
        self,
        request,
        audit: AuditService = Provide[Container.audit_service],
    ):
        audit.log_request(request)
        response = self.get_response(request)
        audit.log_response(response)
        return response
```

Add to `settings.py`:

```python
MIDDLEWARE = [
    "myapp.middleware.AuditMiddleware",
    # ...
]
```
