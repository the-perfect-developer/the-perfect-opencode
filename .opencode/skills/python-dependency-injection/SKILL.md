---
name: python-dependency-injection
description: This skill should be used when the user asks to "implement dependency injection in Python", "use the dependency-injector library", "decouple Python components", "write testable Python services", or needs guidance on Inversion of Control, DI containers, provider types, and wiring in Python applications.
---

# Python Dependency Injection

Dependency Injection (DI) is a design pattern where a class receives its dependencies from an external source rather than constructing them internally. This decouples components, improves testability, and enables flexible configuration without modifying production code.

## Core Concept: Inversion of Control

Inversion of Control (IoC) shifts responsibility for creating and managing dependencies from the dependent class to an external orchestrator (a container or the caller). The class declares what it needs; something else provides it.

**Tight coupling (avoid):**
```python
class UserNotifier:
    def __init__(self):
        self.email = EmailService()  # hard-coded, untestable

    def notify(self, msg):
        self.email.send(msg)
```

**Loose coupling via DI (prefer):**
```python
class UserNotifier:
    def __init__(self, email_service: EmailService):
        self.email_service = email_service  # injected, swappable

    def notify(self, msg):
        self.email_service.send(msg)

notifier = UserNotifier(EmailService())
```

## Injection Styles

| Style | How | When to use |
|---|---|---|
| **Constructor** | Pass via `__init__` | Default; dependencies are required |
| **Setter** | Assign via method after construction | Optional dependencies |
| **Method** | Pass directly to the method call | One-off or per-call dependencies |

Constructor injection is the preferred style. It makes all dependencies explicit and visible at object creation time.

## The `dependency-injector` Library

For production applications, use the `dependency-injector` package (v4.x, BSD licensed, Python ≥ 3.8):

```bash
pip install dependency-injector
```

### Container-Provider Architecture

The framework organizes everything around two primitives:

- **Container** — the central registry; declares all dependencies and how they are built
- **Provider** — defines how a single dependency instance is created

```python
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    api_client = providers.Singleton(
        ApiClient,
        api_key=config.api_key,
        timeout=config.timeout,
    )

    service = providers.Factory(
        Service,
        api_client=api_client,
    )
```

### Provider Types

| Provider | Behavior | Use case |
|---|---|---|
| `Singleton` | Single shared instance for entire app lifetime | DB connections, API clients, caches |
| `Factory` | New instance on every call | Request handlers, per-operation objects |
| `Configuration` | Reads from env vars, YAML, JSON, ini | App settings |
| `Resource` | Managed lifecycle with setup/teardown | DB sessions, file handles |
| `Callable` | Wraps any callable | Functions, class methods |
| `Object` | Provides a fixed value | Constants, pre-built objects |
| `Selector` | Selects a provider based on config | Environment-based switching |

### Configuration Provider

Load settings from multiple sources:

```python
class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

container = Container()
container.config.api_key.from_env("API_KEY", required=True)
container.config.timeout.from_env("TIMEOUT", as_=int, default=5)
# Also supports: .from_yaml(), .from_ini(), .from_dict(), .from_pydantic()
```

### Wiring: Auto-inject into Functions

Wiring eliminates manual dependency passing in function calls. Decorate a function with `@inject`, mark parameters with `Provide[...]`, then call `container.wire()`:

```python
from dependency_injector.wiring import inject, Provide

@inject
def main(service: Service = Provide[Container.service]) -> None:
    service.do_work()

if __name__ == "__main__":
    container = Container()
    container.config.from_env(...)
    container.wire(modules=[__name__])
    main()  # service is injected automatically
```

Wire entire packages at once: `container.wire(packages=["myapp"])`.

## Overriding for Tests

Override any provider without modifying application code:

```python
# In tests
with container.api_client.override(mock.Mock()):
    main()  # the mock is injected instead
```

Or using the `dependency-injector` testing helpers:

```python
def test_service_behavior():
    container = Container()
    container.db.override(providers.Factory(FakeDB))

    service = container.service()
    assert service.get_data() == "expected"
```

FastAPI equivalent via `dependency_overrides`:

```python
app.dependency_overrides[get_db_session] = lambda: FakeDBSession()
```

## Resource Provider: Managed Lifecycle

Use `Resource` for dependencies that require explicit setup and teardown:

```python
from dependency_injector import resources

class DatabaseResource(resources.Resource):
    def init(self) -> Database:
        db = Database(url=self.config.db_url())
        db.connect()
        return db

    def shutdown(self, db: Database) -> None:
        db.disconnect()

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()
    db = providers.Resource(DatabaseResource, config=config)

# Usage
container = Container()
container.init_resources()
# ... use container.db() ...
container.shutdown_resources()
```

## Async Injection

The framework supports async resources and FastAPI's native `Depends()`:

```python
# dependency-injector async resource
class AsyncDBResource(resources.AsyncResource):
    async def init(self) -> AsyncDB:
        db = AsyncDB()
        await db.connect()
        return db

    async def shutdown(self, db: AsyncDB) -> None:
        await db.disconnect()

# FastAPI native async dependency
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session

@app.get("/items")
async def read_items(db: AsyncSession = Depends(get_db)):
    ...
```

## Best Practices

**Program to abstractions:**
```python
from abc import ABC, abstractmethod

class MessageSender(ABC):
    @abstractmethod
    def send(self, message: str) -> None: ...

class EmailSender(MessageSender):
    def send(self, message: str) -> None:
        print(f"Email: {message}")

class SMSSender(MessageSender):
    def send(self, message: str) -> None:
        print(f"SMS: {message}")

# Container switches implementation without changing consumer
class Container(containers.DeclarativeContainer):
    sender = providers.Factory(EmailSender)  # swap to SMSSender anytime
```

**Centralize dependency configuration** — define all providers in one container module, not scattered across the codebase.

**Avoid circular dependencies** — if A depends on B and B depends on A, restructure or use a factory provider to delay instantiation.

**Use the right scope** — `Singleton` for stateless shared resources; `Factory` for stateful per-request objects. Mismatched scopes cause subtle state leakage bugs.

**Lock dependency versions** — pin exact versions in a lock file (`poetry.lock`, pip-compile output) to avoid dependency confusion attacks.

## Anti-Patterns to Avoid

| Anti-pattern | Problem | Fix |
|---|---|---|
| **Service Locator** | `container.get(Service)` inside business logic hides dependencies | Inject explicitly via constructor or `@inject` |
| **Over-injection** | 10+ constructor params | Split into smaller, focused classes |
| **Tight coupling** | `self.dep = ConcreteClass()` inside `__init__` | Accept dependency as parameter |
| **Scope mismanagement** | `Singleton` wrapping a stateful request-scoped object | Use `Factory` or `Resource` with correct scope |
| **Monkey-patching in tests** | `module.SomeClass = MockClass` | Use `container.override()` or `dependency_overrides` |

## Quick Reference

```bash
pip install dependency-injector          # base
pip install "dependency-injector[yaml]"  # + YAML config support
pip install "dependency-injector[pydantic2]"  # + Pydantic v2 settings
```

```python
# Minimal working container
from dependency_injector import containers, providers
from dependency_injector.wiring import inject, Provide

class Container(containers.DeclarativeContainer):
    config  = providers.Configuration()
    service = providers.Factory(MyService, setting=config.setting)

@inject
def handler(svc: MyService = Provide[Container.service]):
    svc.run()

container = Container()
container.config.from_dict({"setting": "value"})
container.wire(modules=[__name__])
handler()
```

## Additional Resources

For detailed coverage of advanced topics, consult:

- **`references/patterns.md`** — Scoped dependencies, multiple containers, selector providers, and testing patterns
- **`references/framework-integration.md`** — Step-by-step integration with Flask, Django, and FastAPI including wiring setup
