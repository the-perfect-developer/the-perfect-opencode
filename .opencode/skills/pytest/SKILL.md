---
name: pytest
description: This skill should be used when the user asks to "write pytest tests", "set up pytest best practices", "configure pytest", "write fixtures", or needs guidance on pytest testing patterns and project structure.
---

# pytest Best Practices

Comprehensive guidance for writing maintainable, efficient test suites with pytest, grounded in the official pytest documentation.

## Project Layout

Use the `src` layout with tests outside the application package:

```
pyproject.toml
src/
    mypkg/
        __init__.py
        app.py
tests/
    conftest.py
    test_app.py
```

Configure `importlib` import mode in `pyproject.toml` (recommended for new projects):

```toml
[tool.pytest.ini_options]
addopts = ["--import-mode=importlib"]
testpaths = ["tests"]
```

Install the package in editable mode so tests run against the local source:

```bash
pip install -e .
```

## Test Discovery Conventions

- Name test files `test_*.py` or `*_test.py`
- Name test functions and methods with a `test_` prefix
- Use `Test`-prefixed classes (no `__init__` method) to group related tests
- Place shared fixtures and plugins in `conftest.py` at the appropriate directory level

## Assertions

Use plain `assert` statements — pytest rewrites them for detailed failure messages:

```python
def test_addition():
    assert 1 + 1 == 2

def test_with_message():
    result = compute()
    assert result > 0, f"Expected positive, got {result}"
```

**Floating-point comparisons** — use `pytest.approx` instead of manual tolerance checks:

```python
def test_floats():
    assert 0.1 + 0.2 == pytest.approx(0.3)
```

**Exception assertions** — use `pytest.raises` as a context manager:

```python
def test_zero_division():
    with pytest.raises(ZeroDivisionError):
        1 / 0

def test_exception_message():
    with pytest.raises(ValueError, match=r"invalid value"):
        parse_value("bad")
```

Never return a boolean from a test function — pytest ignores return values.

## Fixtures

Fixtures are the primary mechanism for test setup and teardown. Define them in `conftest.py` for shared use, or directly in test modules for local use.

### Basic fixture

```python
import pytest

@pytest.fixture
def user():
    return {"name": "Alice", "role": "admin"}

def test_user_role(user):
    assert user["role"] == "admin"
```

### Yield fixtures for teardown (preferred over `addfinalizer`)

```python
@pytest.fixture
def db_connection():
    conn = create_connection()
    yield conn          # test runs here
    conn.close()        # teardown
```

### Fixture scope — choose the broadest scope that is still safe

| Scope | Lifetime | Use case |
|-------|----------|----------|
| `function` | Per test (default) | Mutable state, cheap to create |
| `class` | Per test class | Shared state within a class |
| `module` | Per test file | Expensive setup shared across a module |
| `session` | Entire test run | Database connections, containers |

```python
@pytest.fixture(scope="session")
def app_config():
    return load_config("test.env")
```

### Safe fixture structure

Limit each fixture to **one state-changing action**, paired with its own teardown. This ensures cleanup runs even when other fixtures fail:

```python
@pytest.fixture
def created_user(admin_client):
    user = admin_client.create_user(name="test")
    yield user
    admin_client.delete_user(user)   # always runs
```

### Factory fixtures — for multiple instances in one test

```python
@pytest.fixture
def make_order():
    orders = []
    def _make(product, qty):
        order = Order(product=product, qty=qty)
        orders.append(order)
        return order
    yield _make
    for o in orders: o.cancel()

def test_two_orders(make_order):
    o1 = make_order("book", 1)
    o2 = make_order("pen", 5)
    assert o1.product != o2.product
```

### `conftest.py` placement

- Root `conftest.py` — session-wide fixtures (DB, config)
- `tests/unit/conftest.py` — fixtures scoped to unit tests only
- Fixtures are visible to all tests in the same directory and below

## Parametrization

### `@pytest.mark.parametrize` — avoid duplicate test logic

```python
@pytest.mark.parametrize("value,expected", [
    (2, 4),
    (3, 9),
    (-1, 1),
])
def test_square(value, expected):
    assert square(value) == expected
```

Use `pytest.param` to attach marks to individual cases:

```python
@pytest.mark.parametrize("n", [
    0,
    pytest.param(-1, marks=pytest.mark.xfail(reason="negative not supported")),
])
def test_sqrt(n):
    assert sqrt(n) >= 0
```

### Parametrized fixtures — run entire test sets against multiple configurations

```python
@pytest.fixture(params=["sqlite", "postgres"])
def db(request):
    return create_db(request.param)
```

## Markers

Register all custom markers in `pyproject.toml` to prevent typo-silent failures:

```toml
[tool.pytest.ini_options]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: requires external services",
    "unit: fast, isolated tests",
]
```

Enable strict marker validation to turn unknown markers into errors:

```toml
[tool.pytest.ini_options]
addopts = ["--strict-markers"]
```

Apply markers to individual tests, classes, or whole modules:

```python
@pytest.mark.slow
def test_heavy_computation(): ...

# Module-level
pytestmark = pytest.mark.integration
```

## Configuration (`pyproject.toml`)

Centralise all pytest settings:

```toml
[tool.pytest.ini_options]
addopts = [
    "--import-mode=importlib",
    "--strict-markers",
    "--strict-config",
    "-ra",           # show summary of all non-passing tests
]
testpaths = ["tests"]
markers = [
    "slow: deselect with '-m \"not slow\"'",
    "integration: requires live services",
]
```

Enable strict mode for maximum safety on pinned pytest versions:

```toml
[tool.pytest.ini_options]
strict = true
```

## Skipping and Expected Failures

Use `skipif` for condition-based skips; document the reason:

```python
@pytest.mark.skipif(sys.platform == "win32", reason="POSIX only")
def test_symlinks(): ...
```

Use `xfail` to document known broken behaviour; add `strict=True` once fixed:

```python
@pytest.mark.xfail(reason="issue #42: parser bug", strict=False)
def test_parser_edge_case(): ...
```

## monkeypatch — preferred over `unittest.mock` for simple patching

```python
def test_env_override(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key")
    assert get_api_key() == "test-key"

def test_function_patch(monkeypatch):
    monkeypatch.setattr("mymodule.fetch", lambda url: {"ok": True})
    assert fetch_data() == {"ok": True}
```

`monkeypatch` automatically reverts all changes after the test — no manual cleanup needed.

## Temporary Files

Use `tmp_path` (a `pathlib.Path`) instead of `tempfile`:

```python
def test_writes_file(tmp_path):
    out = tmp_path / "result.txt"
    write_report(out)
    assert out.read_text() == "done"
```

## Quick Reference

| Goal | Tool |
|------|------|
| Assert equality | `assert a == b` |
| Assert float equality | `pytest.approx` |
| Assert exception raised | `pytest.raises()` |
| Assert warning emitted | `pytest.warns()` |
| Skip conditionally | `@pytest.mark.skipif` |
| Document known failure | `@pytest.mark.xfail` |
| Run test N times with data | `@pytest.mark.parametrize` |
| Shared setup/teardown | `@pytest.fixture` |
| Patch objects/env | `monkeypatch` |
| Temp files | `tmp_path` |

## Additional Resources

### Reference Files

- **`references/fixtures.md`** — Fixture scopes, autouse, factory pattern, safe teardown patterns
- **`references/configuration.md`** — Full `pyproject.toml` / `pytest.ini` option reference and strict mode details
