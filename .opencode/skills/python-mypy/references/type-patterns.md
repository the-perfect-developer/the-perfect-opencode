# mypy Type Patterns

Advanced type annotation patterns for real-world Python code.

## Table of Contents

- [Generics](#generics)
- [TypeVar and Constraints](#typevar-and-constraints)
- [ParamSpec and Concatenate](#paramspec-and-concatenate)
- [Overloads](#overloads)
- [Protocols](#protocols)
- [TypedDict Patterns](#typeddict-patterns)
- [Literal Types](#literal-types)
- [Final and ClassVar](#final-and-classvar)
- [Async Patterns](#async-patterns)
- [Runtime Type Safety](#runtime-type-safety)

## Generics

Use generics to write reusable, type-safe containers and utilities.

### Generic Classes (Python 3.12+ syntax)

```python
# Python 3.12+
class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []

    def push(self, item: T) -> None:
        self._items.append(item)

    def pop(self) -> T:
        return self._items.pop()

    def peek(self) -> T | None:
        return self._items[-1] if self._items else None
```

### Generic Classes (Pre-3.12 syntax)

```python
from typing import Generic, TypeVar

T = TypeVar("T")

class Stack(Generic[T]):
    def __init__(self) -> None:
        self._items: list[T] = []

    def push(self, item: T) -> None:
        self._items.append(item)

    def pop(self) -> T:
        return self._items.pop()
```

### Generic Functions

```python
from collections.abc import Sequence

def first(items: Sequence[T]) -> T | None:
    return items[0] if items else None

def zip_with[A, B, C](
    fn: Callable[[A, B], C],
    xs: Iterable[A],
    ys: Iterable[B],
) -> list[C]:
    return [fn(x, y) for x, y in zip(xs, ys)]
```

## TypeVar and Constraints

### Constrained TypeVar

```python
from typing import TypeVar

# Only int or str allowed
Numeric = TypeVar("Numeric", int, float)

def double(x: Numeric) -> Numeric:
    return x * 2  # type: ignore[return-value]  # multiplication returns same type

# Bound TypeVar — T must be a subtype of the bound
from collections.abc import Sized

S = TypeVar("S", bound=Sized)

def length(x: S) -> int:
    return len(x)
```

### Self Type (Python 3.11+)

```python
from typing import Self

class Builder:
    def __init__(self) -> None:
        self._config: dict[str, str] = {}

    def set(self, key: str, value: str) -> Self:
        self._config[key] = value
        return self

class ExtendedBuilder(Builder):
    def set_env(self, env: str) -> Self:  # returns ExtendedBuilder, not Builder
        return self.set("env", env)

# Works correctly with subclasses
b: ExtendedBuilder = ExtendedBuilder().set("x", "1").set_env("prod")
```

## ParamSpec and Concatenate

`ParamSpec` enables typing decorators that preserve the signature of the decorated function.

```python
from collections.abc import Callable
from typing import ParamSpec, TypeVar
import functools

P = ParamSpec("P")
R = TypeVar("R")

def retry(times: int) -> Callable[[Callable[P, R]], Callable[P, R]]:
    def decorator(fn: Callable[P, R]) -> Callable[P, R]:
        @functools.wraps(fn)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            for attempt in range(times):
                try:
                    return fn(*args, **kwargs)
                except Exception:
                    if attempt == times - 1:
                        raise
            raise RuntimeError("unreachable")
        return wrapper
    return decorator

@retry(times=3)
def fetch_data(url: str, timeout: int = 30) -> bytes:
    ...

# mypy knows fetch_data still takes (url: str, timeout: int = 30) -> bytes
```

## Overloads

Use `@overload` when a function's return type depends on the type of its arguments.

```python
from typing import overload

@overload
def parse(value: str) -> int: ...
@overload
def parse(value: bytes) -> str: ...

def parse(value: str | bytes) -> int | str:
    if isinstance(value, str):
        return int(value)
    return value.decode()

result1: int = parse("42")   # mypy knows: int
result2: str = parse(b"hi")  # mypy knows: str
```

### Overload with Literal

```python
from typing import Literal

@overload
def open_file(path: str, mode: Literal["r"]) -> str: ...
@overload
def open_file(path: str, mode: Literal["rb"]) -> bytes: ...
@overload
def open_file(path: str, mode: str) -> str | bytes: ...

def open_file(path: str, mode: str) -> str | bytes:
    with open(path, mode) as f:
        return f.read()
```

## Protocols

Protocols define structural interfaces — any class with the right methods satisfies the protocol, without inheritance.

### Runtime-Checkable Protocol

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Drawable(Protocol):
    def draw(self) -> None: ...
    def resize(self, factor: float) -> None: ...

class Circle:
    def draw(self) -> None:
        print("○")
    def resize(self, factor: float) -> None:
        self.radius *= factor

def render(shape: Drawable) -> None:
    shape.draw()

render(Circle())  # works — Circle satisfies Drawable structurally
assert isinstance(Circle(), Drawable)  # works because @runtime_checkable
```

### Protocol with Properties

```python
class Named(Protocol):
    @property
    def name(self) -> str: ...

class Repository(Protocol):
    def get(self, key: str) -> str | None: ...
    def set(self, key: str, value: str) -> None: ...
    def delete(self, key: str) -> bool: ...
```

## TypedDict Patterns

### Inheritance and Composition

```python
from typing import TypedDict

class BaseEvent(TypedDict):
    event_id: str
    timestamp: float

class UserEvent(BaseEvent):
    user_id: str
    action: str

class PaymentEvent(BaseEvent):
    amount: float
    currency: str
```

### Optional Keys with NotRequired

```python
from typing import TypedDict, NotRequired  # Python 3.11+
# or: from typing_extensions import NotRequired  # older Python

class Config(TypedDict):
    host: str
    port: int
    debug: NotRequired[bool]
    timeout: NotRequired[float]
```

### Narrowing TypedDict Unions

```python
from typing import Literal, TypedDict

class SuccessResponse(TypedDict):
    status: Literal["ok"]
    data: list[str]

class ErrorResponse(TypedDict):
    status: Literal["error"]
    message: str

Response = SuccessResponse | ErrorResponse

def handle(response: Response) -> None:
    if response["status"] == "ok":
        # mypy narrows to SuccessResponse
        print(response["data"])
    else:
        # mypy narrows to ErrorResponse
        print(response["message"])
```

## Literal Types

```python
from typing import Literal

Direction = Literal["north", "south", "east", "west"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

def move(direction: Direction, steps: int) -> None:
    ...

def log(message: str, level: LogLevel = "INFO") -> None:
    ...

move("north", 3)  # ok
move("up", 3)     # mypy error: Argument 1 has incompatible type "Literal['up']"
```

## Final and ClassVar

```python
from typing import Final, ClassVar

# Final — value cannot be reassigned
MAX_RETRIES: Final = 3
API_URL: Final[str] = "https://api.example.com"

class Config:
    # ClassVar — shared across all instances, not per-instance
    default_timeout: ClassVar[int] = 30
    instances: ClassVar[list["Config"]] = []

    # Final instance attribute — set once in __init__, never reassigned
    def __init__(self, name: str) -> None:
        self.name: Final = name
```

## Async Patterns

```python
import asyncio
from collections.abc import AsyncGenerator, AsyncIterator

# Coroutine return types
async def fetch(url: str) -> bytes:
    ...

# Async generator
async def stream_lines(path: str) -> AsyncGenerator[str, None]:
    async with aiofiles.open(path) as f:
        async for line in f:
            yield line.rstrip()

# Async iterator protocol
class EventStream:
    def __aiter__(self) -> AsyncIterator[dict[str, str]]:
        return self

    async def __anext__(self) -> dict[str, str]:
        ...
```

## Runtime Type Safety

### assert_never for Exhaustive Checks

```python
from typing import assert_never, Literal

Status = Literal["pending", "active", "closed"]

def handle_status(status: Status) -> str:
    if status == "pending":
        return "waiting"
    elif status == "active":
        return "running"
    elif status == "closed":
        return "done"
    else:
        assert_never(status)  # mypy error if Status gets a new value not handled
```

### TypeGuard for Custom Narrowing

```python
from typing import TypeGuard

def is_string_list(val: list[object]) -> TypeGuard[list[str]]:
    return all(isinstance(x, str) for x in val)

def process(items: list[object]) -> None:
    if is_string_list(items):
        # mypy narrows: items is list[str] here
        print(", ".join(items))
```

### cast — Use Only as a Last Resort

```python
from typing import cast

# Use cast only when mypy cannot infer the correct type and you are certain
result = some_untyped_api()
typed_result = cast(dict[str, list[int]], result)

# Prefer TypeGuard or isinstance checks over cast when possible
```

## Common Patterns Summary

| Use Case | Pattern |
|---|---|
| Reusable container | `Generic[T]` / `class Foo[T]:` |
| Preserve decorator signature | `ParamSpec` |
| Return type depends on arg type | `@overload` |
| Structural interface | `Protocol` |
| Structured dict | `TypedDict` |
| Enum-like string values | `Literal[...]` |
| Immutable constant | `Final` |
| Shared class state | `ClassVar` |
| Custom type narrowing | `TypeGuard` |
| Exhaustiveness check | `assert_never` |
| Fluent builder subclassing | `Self` |
