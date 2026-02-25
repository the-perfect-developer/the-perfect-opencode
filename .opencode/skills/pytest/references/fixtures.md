# Fixtures Deep Dive

## Table of Contents

1. [Requesting Fixtures](#requesting-fixtures)
2. [Scopes](#scopes)
3. [Teardown Patterns](#teardown-patterns)
4. [Safe Teardown Structure](#safe-teardown-structure)
5. [Autouse Fixtures](#autouse-fixtures)
6. [Factory as Fixture](#factory-as-fixture)
7. [Parametrized Fixtures](#parametrized-fixtures)
8. [Fixture Introspection](#fixture-introspection)
9. [Scope Pitfalls](#scope-pitfalls)

---

## Requesting Fixtures

Tests declare fixtures by name in their parameter list. Pytest resolves and executes them automatically:

```python
@pytest.fixture
def db():
    return Database(":memory:")

def test_insert(db):          # db fixture injected here
    db.insert({"id": 1})
    assert db.count() == 1
```

Fixtures can request other fixtures — dependency graphs are resolved automatically:

```python
@pytest.fixture
def admin_user(db):           # db is injected into this fixture
    return db.create_user(role="admin")

def test_admin_panel(admin_user):
    assert admin_user.can_access("/admin")
```

Within a single test, each fixture is executed **at most once** — the cached result is reused for all dependants.

---

## Scopes

| Scope | Created | Destroyed | Best for |
|-------|---------|-----------|----------|
| `function` | Before each test | After each test | Mutable state; cheap resources |
| `class` | Before first test in class | After last test in class | Shared state within a test class |
| `module` | Before first test in module | After last test in module | File I/O, module-level config |
| `package` | Before first test in package | After last test in package | Package-level shared resources |
| `session` | Once per test run | End of test run | DB connections, spawned processes |

**Rule**: a fixture may only use fixtures of the same or **broader** scope. A `function`-scoped fixture can use a `session`-scoped one, but not vice-versa.

### Dynamic scope

Use a callable when scope must vary by environment (e.g., CI vs. local):

```python
def determine_scope(fixture_name, config):
    if config.getoption("--keep-containers", default=None):
        return "session"
    return "function"

@pytest.fixture(scope=determine_scope)
def docker_container():
    yield spawn_container()
```

---

## Teardown Patterns

### Yield fixtures (recommended)

Place setup code before `yield`, teardown code after. Teardown runs even if the test fails:

```python
@pytest.fixture
def temp_table(db):
    db.execute("CREATE TABLE tmp_data (id INT)")
    yield "tmp_data"
    db.execute("DROP TABLE IF EXISTS tmp_data")
```

Multiple yield fixtures tear down in **reverse order** of creation (LIFO):

```python
@pytest.fixture
def setup_a():
    print("setup A")
    yield
    print("teardown A")   # runs second

@pytest.fixture
def setup_b(setup_a):
    print("setup B")
    yield
    print("teardown B")   # runs first
```

### `addfinalizer` (use only when yield is insufficient)

Useful when teardown must be registered conditionally or incrementally:

```python
@pytest.fixture
def resource(request):
    r = allocate()
    request.addfinalizer(r.release)
    return r
```

Finalizers execute in LIFO order (last registered, first called).

---

## Safe Teardown Structure

**Problem**: if a monolithic setup fixture raises partway through, none of its teardown runs:

```python
# Fragile — if create_user() fails, nothing is cleaned up
@pytest.fixture
def setup():
    user = db.create_user()
    session = browser.open()
    yield user, session
    session.close()
    db.delete_user(user)
```

**Solution**: one fixture per state-changing action, each with its own teardown:

```python
@pytest.fixture
def user(db):
    u = db.create_user(name="test")
    yield u
    db.delete_user(u)          # runs even if browser fixture fails

@pytest.fixture
def browser():
    b = Browser()
    yield b
    b.close()                  # independent teardown

def test_login(user, browser):
    browser.login(user)
    assert browser.title == "Dashboard"
```

If `browser` fails during setup, `user` teardown still runs because it already yielded successfully.

---

## Autouse Fixtures

`autouse=True` applies a fixture to every test in its scope without explicit request:

```python
# conftest.py
@pytest.fixture(autouse=True)
def reset_db(db):
    yield
    db.rollback()          # runs after every test automatically
```

Scope of an autouse fixture determines which tests it applies to:

- In a `conftest.py` → applies to all tests in that directory tree
- In a test module → applies to all tests in that module
- In a test class with `scope="class"` → applies to all tests in that class

**Prefer explicit requests** for clarity; use `autouse` only for truly universal setup (logging, DB rollbacks, clock freezing).

---

## Factory as Fixture

Return a callable when a test needs to create multiple instances dynamically:

```python
@pytest.fixture
def make_invoice():
    invoices = []

    def _create(amount, currency="USD"):
        inv = Invoice(amount=amount, currency=currency)
        invoices.append(inv)
        return inv

    yield _create

    for inv in invoices:
        inv.void()          # clean up all created invoices

def test_invoice_totals(make_invoice):
    a = make_invoice(100)
    b = make_invoice(200)
    assert a.amount + b.amount == 300
```

The factory fixture owns the lifecycle of all objects it creates.

---

## Parametrized Fixtures

Run entire test sets against multiple configurations without duplicating tests:

```python
@pytest.fixture(params=["v1", "v2"])
def api_client(request):
    return ApiClient(version=request.param)

def test_list_users(api_client):       # runs twice: v1 and v2
    users = api_client.list_users()
    assert len(users) > 0
```

Use `ids` for readable test names:

```python
@pytest.fixture(params=[
    pytest.param("sqlite", id="sqlite"),
    pytest.param("postgres", id="postgres"),
])
def db_engine(request):
    return create_engine(request.param)
```

Apply marks to individual parameter values:

```python
@pytest.fixture(params=[
    "fast_backend",
    pytest.param("slow_backend", marks=pytest.mark.slow),
])
def backend(request):
    return request.param
```

---

## Fixture Introspection

Access test metadata inside a fixture via the `request` object:

```python
@pytest.fixture
def logged_action(request):
    print(f"Running: {request.node.name}")
    yield
    print(f"Finished: {request.node.name}")
```

Read module-level configuration from the test context:

```python
@pytest.fixture(scope="module")
def server_url(request):
    # test module can override: server_url = "http://staging"
    return getattr(request.module, "server_url", "http://localhost")
```

Pass data from a test to a fixture using markers:

```python
@pytest.fixture
def permissions(request):
    marker = request.node.get_closest_marker("require_permissions")
    return marker.args if marker else []

@pytest.mark.require_permissions("read", "write")
def test_editor_access(permissions):
    assert "write" in permissions
```

---

## Scope Pitfalls

**Broader scope fixtures must not depend on narrower scope fixtures.**

This will raise an error:

```python
@pytest.fixture(scope="session")
def config():
    return load_config()

@pytest.fixture(scope="function")     # function-scoped
def db(config):
    return Database(config)           # OK — function uses session

@pytest.fixture(scope="session")
def session_db(db):                   # ERROR — session using function-scoped db
    return db
```

**Shared mutable state** in broad-scope fixtures causes test pollution. Prefer immutable data or per-test copies for `session`/`module`-scoped fixtures. Use `scope="function"` by default; only promote scope when the creation cost justifies it.
