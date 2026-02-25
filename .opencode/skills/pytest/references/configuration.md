# pytest Configuration Reference

## Table of Contents

1. [Configuration File Locations](#configuration-file-locations)
2. [pyproject.toml Reference](#pyprojecttoml-reference)
3. [Strict Mode](#strict-mode)
4. [Key Options Explained](#key-options-explained)
5. [Markers Configuration](#markers-configuration)
6. [Test Discovery Tuning](#test-discovery-tuning)
7. [Import Modes](#import-modes)
8. [CI Configuration](#ci-configuration)
9. [Recommended Baseline](#recommended-baseline)

---

## Configuration File Locations

pytest reads configuration from the first file it finds in the project root (searched in order):

1. `pyproject.toml` (section `[tool.pytest.ini_options]`) — **preferred**
2. `pytest.ini`
3. `tox.ini` (section `[pytest]`)
4. `setup.cfg` (section `[tool:pytest]`) — not recommended for new projects

Use `pyproject.toml` for all new projects to centralise tooling configuration.

---

## pyproject.toml Reference

```toml
[tool.pytest.ini_options]

# --- Discovery ---
testpaths = ["tests"]               # where to look for tests
python_files = ["test_*.py"]        # file name patterns
python_classes = ["Test*"]          # class name patterns
python_functions = ["test_*"]       # function name patterns
norecursedirs = [".git", "venv", "dist", "build", "__pycache__"]

# --- Import ---
addopts = ["--import-mode=importlib"]

# --- Output ---
addopts = ["-ra", "--tb=short"]     # show all non-passing; short tracebacks

# --- Strictness ---
addopts = ["--strict-markers", "--strict-config"]

# --- Warnings ---
filterwarnings = [
    "error",                        # turn all warnings into errors
    "ignore::DeprecationWarning",   # except known ones
]

# --- Timeouts (requires pytest-timeout plugin) ---
timeout = 30

# --- Markers ---
markers = [
    "slow: marks tests as slow",
    "integration: requires external services",
    "unit: isolated unit tests",
]
```

Merge `addopts` entries into a single list:

```toml
[tool.pytest.ini_options]
addopts = [
    "--import-mode=importlib",
    "--strict-markers",
    "--strict-config",
    "-ra",
]
```

---

## Strict Mode

Enable `strict = true` to activate all strictness options at once. **Only use with a pinned pytest version** — new strict options added in future releases will apply automatically.

```toml
[tool.pytest.ini_options]
strict = true
```

Individual options (use when you cannot pin the pytest version):

| Option | Effect |
|--------|--------|
| `strict_markers = true` | Unknown markers cause an error instead of a warning |
| `strict_config = true` | Unrecognised config keys cause an error |
| `strict_parametrization_ids = true` | Duplicate parametrize IDs cause an error |
| `strict_xfail = true` | `xfail` tests that pass unexpectedly become failures |

Disable a single option while keeping the rest of strict mode:

```toml
[tool.pytest.ini_options]
strict = true
strict_parametrization_ids = false  # override one option
```

---

## Key Options Explained

### `--import-mode=importlib`

The legacy `prepend` mode inserts directories into `sys.path`, causing:
- Test file name collisions (two `test_models.py` in different folders)
- Local source code shadowing installed packages

`importlib` mode resolves test modules without `sys.path` manipulation — use it for all new projects.

### `-ra`

Show a short summary of all results except passed (`a` = all except passed). Equivalent options:
- `-r a` — show all (including passed)
- `-r f` — show failures only
- `-r N` — show nothing

### `--tb=short`

Shorter traceback format. Options: `short`, `long`, `line`, `no`, `native`, `auto`.

### `filterwarnings = ["error"]`

Converts all Python warnings to errors — highly recommended. Add `ignore::` entries for expected/unavoidable warnings:

```toml
filterwarnings = [
    "error",
    "ignore::DeprecationWarning:pkg_resources",
    "ignore::PendingDeprecationWarning",
]
```

---

## Markers Configuration

All custom markers must be declared to avoid silent typos:

```toml
[tool.pytest.ini_options]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks tests requiring live external services",
    "unit: fast, fully isolated tests",
    "smoke: subset of tests that must pass for deployment",
]
addopts = ["--strict-markers"]
```

Run tests by marker:

```bash
pytest -m "unit"                 # only unit tests
pytest -m "not slow"             # exclude slow tests
pytest -m "integration or smoke" # boolean expressions
```

Register markers programmatically (for plugins):

```python
# conftest.py
def pytest_configure(config):
    config.addinivalue_line("markers", "db: requires database")
```

---

## Test Discovery Tuning

### Restrict test paths

```toml
[tool.pytest.ini_options]
testpaths = ["tests", "src/mypkg/tests"]
```

### Exclude directories

```toml
[tool.pytest.ini_options]
norecursedirs = [
    ".git", ".tox", "venv", ".venv",
    "dist", "build", "*.egg-info",
]
```

### Collect only specific markers

```bash
pytest -m "unit" --ignore=tests/integration
```

### Run a single test or file

```bash
pytest tests/test_api.py::test_get_user   # single test
pytest tests/test_api.py                  # single file
pytest -k "login"                         # keyword expression
```

---

## Import Modes

| Mode | `sys.path` | Unique filenames required | Recommended |
|------|-----------|--------------------------|-------------|
| `prepend` | Modified (legacy default) | Yes | No |
| `append` | Modified | Yes | No |
| `importlib` | Not modified | No | Yes |

Switch to `importlib`:

```toml
[tool.pytest.ini_options]
addopts = ["--import-mode=importlib"]
```

With `importlib`, test files no longer need unique names across subdirectories — `tests/unit/test_models.py` and `tests/integration/test_models.py` coexist without conflict.

---

## CI Configuration

Install pytest and dependencies in CI the same way as locally:

```bash
pip install -e ".[dev]"    # editable install with dev extras
pytest --tb=short -q       # concise output for CI logs
```

Use `tox` to test against multiple Python versions:

```toml
# tox.ini
[tox]
envlist = py310, py311, py312

[testenv]
deps = pytest
commands = pytest {posargs}
```

Recommended CI flags:

```bash
pytest -x           # stop at first failure (fast feedback)
pytest --tb=long    # full tracebacks for debugging failures
pytest --durations=10  # show 10 slowest tests
```

---

## Recommended Baseline

Minimal production-ready configuration for a new project:

```toml
[tool.pytest.ini_options]
addopts = [
    "--import-mode=importlib",
    "--strict-markers",
    "--strict-config",
    "-ra",
    "--tb=short",
]
testpaths = ["tests"]
filterwarnings = ["error"]
markers = [
    "slow: deselect with '-m \"not slow\"'",
    "integration: requires live external services",
]
```

Editable install + run:

```bash
pip install -e ".[dev]"
pytest
```
