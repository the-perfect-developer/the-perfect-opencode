# Dependency Management — Advanced Reference

## Table of Contents

- [Dependency Fields Overview](#dependency-fields-overview)
- [Version Specifier Syntax](#version-specifier-syntax)
- [Optional Dependencies (Extras)](#optional-dependencies-extras)
- [Development Dependency Groups](#development-dependency-groups)
- [Platform and Python Version Markers](#platform-and-python-version-markers)
- [Dependency Sources](#dependency-sources)
- [Editable Installations](#editable-installations)
- [Build Dependencies](#build-dependencies)
- [Migrating from requirements.txt](#migrating-from-requirementstxt)
- [Conflicting Dependencies](#conflicting-dependencies)

---

## Dependency Fields Overview

uv projects use multiple dependency fields with distinct purposes:

| Field | Location | Published to PyPI | Purpose |
|---|---|---|---|
| `project.dependencies` | `pyproject.toml` | Yes | Runtime requirements |
| `project.optional-dependencies` | `pyproject.toml` | Yes | Optional feature extras |
| `dependency-groups` | `pyproject.toml` | No | Local dev-only dependencies |
| `tool.uv.sources` | `pyproject.toml` | No | Alternative sources (dev override) |
| `build-system.requires` | `pyproject.toml` | Yes | Build-time requirements |

---

## Version Specifier Syntax

uv follows [PEP 508](https://peps.python.org/pep-0508/) dependency specifier syntax.

### Operators

| Specifier | Meaning |
|---|---|
| `>=1.2` | Version 1.2 or later |
| `<=1.2` | Version 1.2 or earlier |
| `==1.2.3` | Exactly 1.2.3 |
| `!=1.2.3` | Anything except 1.2.3 |
| `~=1.2` | Compatible: `>=1.2,<2` |
| `~=1.2.3` | Compatible: `>=1.2.3,<1.3` |
| `==1.2.*` | Any 1.2.x release |

### Combining Constraints

```
# Range: at least 1.2.3 but below 2, excluding 1.4.0
foo >=1.2.3,<2,!=1.4.0

# Any 2.x release
bar ==2.*
```

### Extras in Specifiers

```
# Install pandas with excel and plot extras
pandas[excel,plot] ==2.2

# Extras with version constraints
transformers[torch] >=4.39.3,<5
```

---

## Optional Dependencies (Extras)

Extras allow users to opt into feature-specific dependency sets. Used for published libraries.

```toml
[project.optional-dependencies]
plot = [
    "matplotlib>=3.6.3",
]
excel = [
    "odfpy>=1.4.1",
    "openpyxl>=3.1.0",
    "xlrd>=2.0.1",
    "xlsxwriter>=3.0.5",
]
network = [
    "aiohttp>=3.9",
    "httpx>=0.27",
]
```

Install with extras:

```bash
pip install "my-package[excel,network]"
# or with uv:
uv add "my-package[excel,network]"
```

Add an optional dependency via CLI:

```bash
uv add httpx --optional network
```

### Extras with Custom Sources

Route extras to different indexes:

```toml
[project.optional-dependencies]
cpu = ["torch"]
gpu = ["torch"]

[tool.uv.sources]
torch = [
  { index = "torch-cpu", extra = "cpu" },
  { index = "torch-gpu", extra = "gpu" },
]

[[tool.uv.index]]
name = "torch-cpu"
url = "https://download.pytorch.org/whl/cpu"

[[tool.uv.index]]
name = "torch-gpu"
url = "https://download.pytorch.org/whl/cu124"
```

---

## Development Dependency Groups

Development dependencies use `[dependency-groups]` (PEP 735). They are never published to PyPI.

### Basic Groups

```bash
uv add --dev pytest              # → dependency-groups.dev
uv add --group lint ruff         # → dependency-groups.lint
uv add --group test pytest-cov   # → dependency-groups.test
```

```toml
[dependency-groups]
dev = ["pytest>=8.1.1,<9"]
lint = ["ruff>=0.4.0", "mypy>=1.10"]
test = ["pytest", "pytest-cov>=5.0"]
```

### Nesting Groups

Avoid duplication by including groups inside other groups:

```toml
[dependency-groups]
lint = ["ruff", "mypy"]
test = ["pytest", "pytest-cov"]
dev = [
  {include-group = "lint"},
  {include-group = "test"},
  "ipython",
]
```

### Default Groups

The `dev` group is included by default in `uv run` and `uv sync`. Change defaults:

```toml
[tool.uv]
default-groups = ["dev", "test"]

# Or include all groups by default
default-groups = "all"
```

### Group-Specific Python Requirement

When a group requires a different Python range:

```toml
[project]
requires-python = ">=3.10"

[dependency-groups]
dev = ["pytest"]

[tool.uv.dependency-groups]
dev = {requires-python = ">=3.12"}
```

### Group CLI Flags

| Flag | Effect |
|---|---|
| `--dev` | Include `dev` group |
| `--only-dev` | Only `dev` group |
| `--no-dev` | Exclude `dev` group |
| `--group <name>` | Include named group |
| `--only-group <name>` | Only named group |
| `--no-group <name>` | Exclude named group |
| `--all-groups` | Include all groups |
| `--no-default-groups` | Exclude all default groups |

---

## Platform and Python Version Markers

Use PEP 508 environment markers to add conditional dependencies.

### Common Markers

| Marker | Values |
|---|---|
| `sys_platform` | `linux`, `darwin`, `win32` |
| `platform_system` | `Linux`, `Darwin`, `Windows` |
| `python_version` | `"3.11"`, `"3.12"` etc. |
| `python_full_version` | `"3.11.4"` |
| `implementation_name` | `cpython`, `pypy` |

### Usage Examples

```bash
# Linux only
uv add "jax; sys_platform == 'linux'"

# Python 3.11+
uv add "numpy; python_version >= '3.11'"

# Windows only
uv add "pywin32; platform_system == 'Windows'"

# Backport for older Python
uv add "importlib-metadata>=7.1.0; python_version < '3.10'"
```

### Compound Markers

```
aiohttp >=3.7.4,<4; (sys_platform != 'win32' or implementation_name != 'pypy') and python_version >= '3.10'
```

Note: versions inside markers must be quoted; versions outside markers must not be.

### Platform-Specific Sources

Apply sources conditionally:

```toml
[tool.uv.sources]
httpx = { git = "https://github.com/encode/httpx", tag = "0.27.2", marker = "sys_platform == 'darwin'" }
```

Multiple sources with platform discrimination:

```toml
[tool.uv.sources]
httpx = [
  { git = "https://github.com/encode/httpx", tag = "0.27.2", marker = "sys_platform == 'darwin'" },
  { git = "https://github.com/encode/httpx", tag = "0.24.1", marker = "sys_platform == 'linux'" },
]
```

---

## Dependency Sources

`tool.uv.sources` overrides where packages are fetched **during development only**. Other tools (pip, Poetry) ignore this table.

### Index Source

Pin a package to a specific index:

```bash
uv add torch --index pytorch=https://download.pytorch.org/whl/cpu
```

```toml
[tool.uv.sources]
torch = { index = "pytorch" }

[[tool.uv.index]]
name = "pytorch"
url = "https://download.pytorch.org/whl/cpu"
explicit = true   # only used for packages that reference it explicitly
```

### Git Source

```bash
# HTTPS
uv add git+https://github.com/encode/httpx

# SSH
uv add git+ssh://git@github.com/encode/httpx

# Specific tag
uv add git+https://github.com/encode/httpx --tag 0.27.0

# Specific branch
uv add git+https://github.com/encode/httpx --branch main

# Specific commit
uv add git+https://github.com/encode/httpx --rev 326b943
```

```toml
[tool.uv.sources]
httpx = { git = "https://github.com/encode/httpx", tag = "0.27.0" }
```

### URL Source

Install directly from a URL to a wheel or source distribution:

```bash
uv add "https://files.pythonhosted.org/packages/.../httpx-0.27.0.tar.gz"
```

```toml
[tool.uv.sources]
httpx = { url = "https://files.pythonhosted.org/packages/.../httpx-0.27.0.tar.gz" }
```

### Path Source

```bash
# Absolute path to wheel
uv add /example/foo-0.1.0-py3-none-any.whl

# Relative path to project directory
uv add ../my-lib/

# Editable install from path
uv add --editable ../my-lib/
```

```toml
[tool.uv.sources]
my-lib = { path = "../my-lib", editable = true }
```

### Workspace Member Source

```toml
[project]
dependencies = ["my-pkg==0.1.0"]

[tool.uv.sources]
my-pkg = { workspace = true }

[tool.uv.workspace]
members = ["packages/my-pkg"]
```

Workspace members are always editable installs.

### Disabling Sources

Simulate published package resolution (no local overrides):

```bash
uv lock --no-sources
uv build --no-sources
```

Run before publishing to ensure the package resolves correctly without development sources.

---

## Editable Installations

Editable installs link source files directly into the virtual environment instead of copying them. Changes to source are immediately visible without reinstalling.

```bash
# Add as editable
uv add --editable ../projects/bar/

# Opt out of editable in a workspace
uv add --no-editable ./path/foo
```

```toml
[tool.uv.sources]
bar = { path = "../projects/bar", editable = true }
```

uv uses editable installs for workspace members by default.

**Limitations**:
- The build backend must support editable installs (most modern backends do)
- Native extensions are not automatically recompiled

---

## Build Dependencies

Declare what is needed to build the package (not installed at runtime):

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

Override with a local build backend during development:

```toml
[tool.uv.sources]
hatchling = { path = "./dev/hatchling" }
```

Always validate the published build doesn't depend on `tool.uv.sources` overrides:

```bash
uv build --no-sources
```

---

## Migrating from requirements.txt

Import all dependencies from a `requirements.txt`:

```bash
uv add -r requirements.txt
```

With constraints:

```bash
uv add -r requirements.txt -c constraints.txt
```

After importing, commit the generated `pyproject.toml` and `uv.lock`, then remove `requirements.txt`.

---

## Conflicting Dependencies

When optional or group dependencies conflict, explicitly declare the conflict:

```toml
[tool.uv]
conflicts = [
  [
    { extra = "cpu" },
    { extra = "gpu" },
  ],
]
```

Without this declaration, uv fails resolution when conflicting groups/extras are present.
