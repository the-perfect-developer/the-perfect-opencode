# Advanced DI Patterns

## Table of Contents
1. [Multiple Containers](#multiple-containers)
2. [Scoped Dependencies](#scoped-dependencies)
3. [Selector Provider](#selector-provider)
4. [Testing Patterns](#testing-patterns)
5. [Security Considerations](#security-considerations)
6. [Framework Comparison](#framework-comparison)

---

## Multiple Containers

Split large applications into domain-specific containers and compose them:

```python
# infrastructure/container.py
class InfrastructureContainer(containers.DeclarativeContainer):
    config = providers.Configuration()
    db = providers.Singleton(Database, url=config.db_url)
    cache = providers.Singleton(Redis, host=config.redis_host)

# services/container.py
class ServiceContainer(containers.DeclarativeContainer):
    infra = providers.DependenciesContainer()

    user_service = providers.Factory(
        UserService,
        db=infra.db,
        cache=infra.cache,
    )

# main.py
infra = InfrastructureContainer()
infra.config.from_yaml("config.yaml")

services = ServiceContainer(infra=infra)
```

`DependenciesContainer` acts as a typed placeholder for a dependency container, enabling loose coupling between modules.

---

## Scoped Dependencies

### Request-Scoped (FastAPI)

Create a fresh sub-container per request to avoid state leakage:

```python
from dependency_injector import containers, providers
from fastapi import Request

class RequestContainer(containers.DeclarativeContainer):
    request = providers.Object(None)
    db_session = providers.Resource(DBSessionResource)

@app.middleware("http")
async def di_middleware(request: Request, call_next):
    container = RequestContainer(request=request)
    await container.init_resources()
    request.state.container = container
    response = await call_next(request)
    await container.shutdown_resources()
    return response
```

### Resource Provider Lifecycle

`Resource` providers support context-manager style or explicit init/shutdown:

```python
class ConnectionPool(resources.Resource):
    def init(self) -> Pool:
        pool = create_pool(max_size=10)
        pool.open()
        return pool

    def shutdown(self, pool: Pool) -> None:
        pool.close()

# Context manager usage
container = Container()
with container.db_pool() as pool:
    pool.execute("SELECT 1")
# pool.close() called automatically

# Explicit usage
container.init_resources()
pool = container.db_pool()
container.shutdown_resources()
```

### Singleton vs Factory Decision Guide

| Condition | Use |
|---|---|
| Shared across all requests, stateless | `Singleton` |
| Shared but needs teardown (DB pool) | `Singleton` or `Resource` |
| Unique per request/call | `Factory` |
| Per-request with cleanup (DB session) | `Resource` in request scope |
| Wraps async I/O | `AsyncResource` |

---

## Selector Provider

Switch between implementations based on configuration:

```python
class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    # Selects storage backend from config value
    storage = providers.Selector(
        config.storage_backend,
        s3=providers.Factory(S3Storage, bucket=config.s3_bucket),
        local=providers.Factory(LocalStorage, path=config.local_path),
        memory=providers.Factory(InMemoryStorage),
    )
```

Configure per environment:

```python
# Production
container.config.storage_backend.from_env("STORAGE_BACKEND", default="s3")

# Testing
container.config.storage_backend.override("memory")
```

---

## Testing Patterns

### Pattern 1: Provider Override (Recommended)

Override at the container level; automatically reverts after context:

```python
import pytest
from unittest.mock import MagicMock
from myapp.containers import Container

@pytest.fixture
def container():
    c = Container()
    c.config.from_dict({"db_url": "sqlite:///:memory:"})
    return c

def test_user_creation(container):
    mock_email = MagicMock()
    with container.email_service.override(mock_email):
        service = container.user_service()
        service.create_user("alice@example.com")

    mock_email.send.assert_called_once()
```

### Pattern 2: Pytest Fixtures with Wiring

Wire the container in a session-scoped fixture:

```python
# conftest.py
import pytest
from myapp.containers import Container

@pytest.fixture(scope="session")
def app_container():
    container = Container()
    container.config.from_dict({"setting": "test_value"})
    container.wire(packages=["myapp"])
    yield container
    container.unwire()

@pytest.fixture
def mock_db(app_container):
    with app_container.db.override(FakeDB()):
        yield
```

### Pattern 3: FastAPI Dependency Override

```python
from fastapi.testclient import TestClient
from myapp.main import app
from myapp.dependencies import get_db

def override_get_db():
    db = FakeDatabase()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

def test_read_items():
    response = client.get("/items")
    assert response.status_code == 200
```

### Pattern 4: Constructor Injection in Unit Tests

For simple unit tests, bypass the container entirely:

```python
def test_notifier_sends_alert():
    fake_sender = FakeEmailSender()
    notifier = UserNotifier(email_service=fake_sender)  # direct injection

    notifier.notify("test@example.com", "Hello")

    assert fake_sender.last_recipient == "test@example.com"
```

---

## Security Considerations

### Dependency Confusion

Attackers publish packages to PyPI with internal package names. Mitigations:

1. **Pin exact versions** in `requirements.txt` or lock files:
   ```
   dependency-injector==4.48.3
   ```
2. **Use private package indexes** (Artifactory, CodeArtifact) with `--index-url`
3. **Namespace internal packages** to avoid PyPI name collisions
4. **Hash verification**:
   ```
   pip install --require-hashes -r requirements.txt
   ```

### Configuration Security

Validate all injected configuration before use. Never inject untrusted input directly:

```python
class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    # SAFE: explicit cast and required flag
    db_port = providers.Factory(
        lambda: int(os.environ["DB_PORT"])  # fails fast if missing or invalid
    )

    # AVOID: injecting raw user-supplied strings as connection URLs
```

### Auditing Tools

| Tool | Purpose |
|---|---|
| `pip-audit` | CVE scanning for installed packages |
| `safety check` | Check against known vulnerability database |
| `bandit` | Static analysis for Python security issues |
| `pip install --require-hashes` | Prevent tampered package installs |

Run as part of CI:
```bash
pip-audit --requirement requirements.txt
bandit -r src/
```

---

## Framework Comparison

| Framework | Best for | Strengths | Limitations |
|---|---|---|---|
| `dependency-injector` | Production apps, complex graphs | Full-featured, fast (Cython), typed, async | Verbose setup |
| `injector` | Smaller projects | Clean Google Guice-style API | Fewer features |
| `pinject` | Auto-wiring by name | Minimal boilerplate | Slow (reflection), less maintained |
| `punq` | Microservices | Minimal, fast | Limited scope |
| FastAPI `Depends()` | FastAPI only | Native async, built-in testing support | Not portable |
| `flask-injector` | Flask apps | Easy Flask integration | Depends on `injector` |

### When to Use Each

- **Starting a new production Python service** → `dependency-injector` with `DeclarativeContainer`
- **FastAPI application** → FastAPI `Depends()` for route-level, `dependency-injector` for app-level wiring
- **Small script or CLI** → manual constructor injection (no framework needed)
- **Testing without a framework** → direct constructor injection in test fixtures
