---
name: python-mypy
description: This skill should be used when the user asks to "add mypy to a project", "set up static type checking", "fix mypy errors", "configure mypy", "annotate Python code with types", or needs guidance on Python type checking best practices with mypy.
---

# Python mypy — Static Type Checking

Mypy is an optional static type checker for Python that catches type errors at development time without runtime overhead. It combines the expressive power of Python with a powerful type system based on PEP 484, enabling gradual migration from dynamic to static typing.

## Installation

```bash
pip install mypy

# Install type stubs for common third-party libraries
pip install types-requests types-PyYAML types-boto3

# Run mypy
mypy src/
mypy --strict src/
```

## Core Annotation Patterns

### Functions

Annotate all function signatures — return type and all parameters:

```python
from collections.abc import Iterable, Sequence

def process(items: list[str], limit: int = 10) -> list[str]:
    return items[:limit]

# Use abstract types for parameters (accept more, restrict less)
def summarize(records: Iterable[dict[str, str]]) -> str:
    return ", ".join(r["name"] for r in records)

# None return type for procedures
def log_event(event: str, level: str = "INFO") -> None:
    print(f"[{level}] {event}")
```

### Optional and Union

```python
# Python 3.10+ syntax (preferred)
def find_user(user_id: int) -> str | None:
    ...

# Python 3.9 and earlier
from typing import Optional, Union
def find_user(user_id: int) -> Optional[str]:
    ...

# Union for multiple possible types
def normalize_id(user_id: int | str) -> str:
    if isinstance(user_id, int):
        return f"user-{user_id}"
    return user_id
```

### Classes

```python
from typing import ClassVar

class Repository:
    default_limit: ClassVar[int] = 100

    def __init__(self, name: str, url: str) -> None:
        self.name = name
        self.url = url
        self._cache: dict[str, list[str]] = {}

    def fetch(self, query: str) -> list[str]:
        return self._cache.get(query, [])
```

### TypedDict for Structured Dicts

Use `TypedDict` instead of `dict[str, Any]` for known-structure dictionaries:

```python
from typing import TypedDict

class UserRecord(TypedDict):
    id: int
    name: str
    email: str

class PartialUser(TypedDict, total=False):
    nickname: str
    avatar_url: str

def create_user(data: UserRecord) -> None:
    print(data["name"])  # mypy knows this is str
```

### Protocols for Duck Typing

Prefer `Protocol` over concrete base classes for flexible interfaces:

```python
from typing import Protocol

class Closeable(Protocol):
    def close(self) -> None: ...

class Readable(Protocol):
    def read(self, n: int = -1) -> bytes: ...

def process_stream(stream: Readable) -> bytes:
    return stream.read()
```

## Strictness Levels

Adopt strictness incrementally. Start permissive, tighten over time.

### Recommended Progression

**Level 1 — New project baseline** (`pyproject.toml`):

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
warn_unused_ignores = true
```

**Level 2 — Growing codebase**:

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
warn_unused_ignores = true
disallow_incomplete_defs = true
check_untyped_defs = true
```

**Level 3 — Strict (production-ready)**:

```toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_unused_ignores = true
```

`strict` enables: `disallow_untyped_defs`, `disallow_any_generics`, `warn_return_any`, `no_implicit_reexport`, `strict_equality`, and more.

## Handling Third-Party Libraries

### Install Type Stubs

```bash
# Check if stubs are available
mypy --install-types

# Install specific stubs
pip install types-requests types-PyYAML types-redis
```

### Suppress Missing Stubs Per Module

Avoid global `ignore_missing_imports`. Scope it to specific libraries:

```toml
# pyproject.toml — preferred approach
[[tool.mypy.overrides]]
module = ["boto3.*", "botocore.*", "some_untyped_lib"]
ignore_missing_imports = true
```

### Inline Suppression (Use Sparingly)

```python
import untyped_lib  # type: ignore[import-untyped]

result = complex_dynamic_call()  # type: ignore[no-any-return]  # reason: third-party returns Any
```

Always add a comment explaining why the suppression is necessary.

## Common Use Cases

### Migrating an Existing Codebase

Start with zero annotations and progressively type the codebase:

1. Run `mypy --ignore-missing-imports src/` — establish a zero-error baseline.
2. Enable `check_untyped_defs = true` to catch bugs inside unannotated functions.
3. Add annotations to public API functions first (highest value).
4. Enable `disallow_incomplete_defs` to prevent partially-annotated functions.
5. Gradually enable `disallow_untyped_defs` per package via `[[tool.mypy.overrides]]`.
6. Reach `strict = true` as the final goal.

```toml
# Migrate package-by-package
[[tool.mypy.overrides]]
module = "myapp.core.*"
disallow_untyped_defs = true

[[tool.mypy.overrides]]
module = "myapp.legacy.*"
ignore_errors = true  # deal with later
```

### FastAPI / Pydantic Integration

```python
from pydantic import BaseModel

class Item(BaseModel):
    name: str
    price: float
    tags: list[str] = []

# FastAPI + mypy works seamlessly — Pydantic models are fully typed
from fastapi import FastAPI
app = FastAPI()

@app.get("/items/{item_id}")
async def get_item(item_id: int) -> Item:
    return Item(name="Widget", price=9.99)
```

### SQLAlchemy with mypy Plugin

```toml
[tool.mypy]
plugins = ["sqlalchemy.ext.mypy.plugin"]
```

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str]
    email: Mapped[str | None]
```

### Type Narrowing

Mypy understands `isinstance`, `assert`, and guard patterns:

```python
def render(value: str | int | None) -> str:
    if value is None:
        return ""
    if isinstance(value, int):
        return str(value)
    return value.upper()  # mypy knows: value is str here
```

Use `reveal_type()` during development to inspect inferred types:

```python
x = [1, 2, 3]
reveal_type(x)  # Revealed type is "builtins.list[builtins.int]"
```

## CI Integration

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.9.0
    hooks:
      - id: mypy
        additional_dependencies:
          - types-requests
          - pydantic
```

### GitHub Actions

```yaml
- name: Run mypy
  run: mypy src/ --config-file pyproject.toml
```

## Quick Reference

| Pattern | Syntax |
|---|---|
| Basic function | `def f(x: int) -> str:` |
| Optional param | `x: str \| None = None` |
| List of strings | `list[str]` |
| Dict | `dict[str, int]` |
| Callable | `Callable[[int, str], bool]` |
| Any iterable | `Iterable[str]` |
| Typed dict | `class X(TypedDict): key: type` |
| Protocol | `class X(Protocol): def method(...):` |
| Suppress line | `# type: ignore[error-code]` |
| Debug type | `reveal_type(expr)` |
| Forward ref | `from __future__ import annotations` |

| Flag | Purpose |
|---|---|
| `strict` | Enable all optional checks |
| `disallow_untyped_defs` | Require all function annotations |
| `check_untyped_defs` | Check bodies of unannotated functions |
| `warn_return_any` | Warn on implicit `Any` returns |
| `warn_unused_ignores` | Catch stale `# type: ignore` comments |
| `ignore_missing_imports` | Suppress missing stub errors |

## Additional Resources

For complete configuration options and advanced patterns:

- **`references/configuration-guide.md`** — Complete `pyproject.toml` templates and per-module override patterns
- **`references/type-patterns.md`** — Generics, Protocols, TypeVar, ParamSpec, overloads, and advanced patterns
- **`examples/pyproject.toml`** — Ready-to-use configuration for new and migrating projects
