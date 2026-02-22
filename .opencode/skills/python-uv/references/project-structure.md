# Project Structure — Deep Dive Reference

## Table of Contents

- [File and Directory Overview](#file-and-directory-overview)
- [pyproject.toml Anatomy](#pyprojecttoml-anatomy)
- [The uv.lock Lockfile](#the-uvlock-lockfile)
- [The .python-version File](#the-python-version-file)
- [The .venv Directory](#the-venv-directory)
- [Workspace Layout](#workspace-layout)
- [uv Configuration in pyproject.toml](#uv-configuration-in-pyprojecttoml)
- [Project Packaging vs. Virtual Projects](#project-packaging-vs-virtual-projects)
- [pylock.toml and Export](#pylocktoml-and-export)

---

## File and Directory Overview

A fully initialized uv project:

```
my-project/
├── .gitignore            # Auto-generated, excludes .venv
├── .python-version       # Default Python version (e.g., "3.12")
├── .venv/                # Managed virtual environment — do NOT commit
│   ├── bin/
│   ├── lib/
│   └── pyvenv.cfg
├── README.md
├── pyproject.toml        # Project metadata and dependencies — commit
├── uv.lock               # Exact resolved versions, cross-platform — commit
└── src/
    └── my_project/
        └── __init__.py
```

**Version control rules**:
- Commit: `pyproject.toml`, `uv.lock`, `.python-version`, `README.md`
- Exclude: `.venv/` (uv's generated `.gitignore` handles this automatically)

---

## pyproject.toml Anatomy

### Minimal Valid Project

```toml
[project]
name = "my-project"
version = "0.1.0"
```

### Full Project Definition

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "A short description of the project"
readme = "README.md"
license = { text = "MIT" }
authors = [
    { name = "Author Name", email = "author@example.com" },
]
requires-python = ">=3.11"     # Always set this — prevents accidental installs on unsupported Python
dependencies = [
    "httpx>=0.27.0",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev-extras = ["rich>=13.0"]

[project.urls]
Homepage = "https://example.com"
Repository = "https://github.com/example/my-project"

[project.scripts]
my-cli = "my_project.cli:main"   # Installs 'my-cli' as an executable

[dependency-groups]
dev = [
    {include-group = "lint"},
    {include-group = "test"},
]
lint = ["ruff>=0.4.0", "mypy>=1.10"]
test = ["pytest>=8.0", "pytest-cov>=5.0"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
default-groups = ["dev"]     # Groups included in uv run / uv sync by default

[tool.uv.sources]
# Development-only source overrides (not published)
# my-lib = { path = "../my-lib", editable = true }
```

### Key `[project]` Fields

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Package name (used on PyPI) |
| `version` | Yes | Semantic version string |
| `requires-python` | Recommended | e.g., `">=3.11"` |
| `dependencies` | No | Runtime requirements |
| `readme` | No | Path to README file |
| `license` | No | SPDX expression or file |
| `scripts` | No | CLI entry points |
| `optional-dependencies` | No | Named extras for users |

### Python Version Requirement

Always specify `requires-python` to prevent silent failures on incompatible interpreters:

```toml
[project]
requires-python = ">=3.11"
```

uv uses this to filter compatible packages during resolution.

---

## The uv.lock Lockfile

`uv.lock` is a **universal**, **cross-platform** lockfile in TOML format. It contains:

- Exact resolved versions of every dependency
- Hashes for integrity verification
- Platform and Python version markers
- Resolution for all supported platforms simultaneously

### Why It Is Universal

Unlike `pip freeze` or a platform-specific lockfile, `uv.lock` captures the full resolution for all platforms (Linux, macOS, Windows) and all Python versions within `requires-python`. This means a single committed file serves all developers and CI environments.

### Lifecycle

| Event | Effect on uv.lock |
|---|---|
| `uv add <pkg>` | Updated automatically |
| `uv remove <pkg>` | Updated automatically |
| `uv run` | Auto-updated if pyproject.toml changed |
| `uv sync` | Auto-updated if pyproject.toml changed |
| `uv lock` | Regenerated from pyproject.toml |
| `uv lock --upgrade` | All packages upgraded within constraints |
| `uv lock --upgrade-package <name>` | Single package upgraded |
| `uv lock --check` | Fails if lockfile is out of sync (CI use) |

### CI Validation Pattern

```yaml
# GitHub Actions example
- name: Check lockfile is up to date
  run: uv lock --check
```

### Manual Editing

Never manually edit `uv.lock`. It is fully managed by uv. Direct edits will be overwritten and may corrupt the resolution.

---

## The .python-version File

Specifies the default Python version for the project environment:

```
3.12
```

- Created by `uv init` using the system's available Python
- Used by `uv` when creating `.venv` if no `--python` flag is provided
- Override at any time: `uv python pin 3.11`
- Commit this file so the team uses the same interpreter

uv installs the specified Python version automatically if not present on the system (via the managed Python distribution).

---

## The .venv Directory

The isolated virtual environment lives at `.venv/` in the project root. uv places it here so editors (VS Code, PyCharm, etc.) auto-discover it for code completion and type hints.

### Key Behaviors

- Created on first `uv run`, `uv sync`, or `uv lock`
- Recreated automatically if corrupted or deleted
- Never committed to version control (uv's `.gitignore` entry handles this)
- Managed exclusively by uv — do not install packages via `pip` directly

### Disabling Automatic Management

```toml
[tool.uv]
managed = false
```

Disables auto-lock and auto-sync. Useful when another tool manages the environment.

### Environment Activation (when needed)

```bash
# macOS/Linux
source .venv/bin/activate

# Windows PowerShell
.venv\Scripts\activate

# Windows Command Prompt
.venv\Scripts\activate.bat
```

Prefer `uv run` over manual activation in scripts and CI pipelines.

---

## Workspace Layout

Workspaces group multiple related packages in a single repository under a shared lockfile.

### Structure

```
workspace-root/
├── pyproject.toml        # Workspace root definition
├── uv.lock               # Shared lockfile for all members
├── packages/
│   ├── core/
│   │   └── pyproject.toml
│   └── api/
│       └── pyproject.toml
└── apps/
    └── web/
        └── pyproject.toml
```

### Root pyproject.toml

```toml
[tool.uv.workspace]
members = ["packages/*", "apps/*"]
```

### Member pyproject.toml

```toml
[project]
name = "core"
version = "0.1.0"
dependencies = ["httpx>=0.27"]
```

### Declaring Member Dependencies

```toml
# In packages/api/pyproject.toml
[project]
dependencies = ["core==0.1.0"]

[tool.uv.sources]
core = { workspace = true }
```

Workspace members are always installed as editable installs.

### Workspace Constraints

- All members share a single `uv.lock`
- All member dependency groups must be compatible with each other
- uv resolves all members together — conflicts between members surface at lock time
- Members are discovered by `glob` patterns in `[tool.uv.workspace].members`

---

## uv Configuration in pyproject.toml

Configure uv behavior under `[tool.uv]`:

```toml
[tool.uv]
# Python version for environment creation
python = "3.12"

# Override default included dependency groups
default-groups = ["dev", "test"]

# Disable automatic locking and syncing
managed = false

# Use a different index as primary
index-url = "https://my-private-index.example.com/simple"

# Add extra indexes
extra-index-url = ["https://pypi.org/simple"]

# Pin packages to specific indexes
[[tool.uv.index]]
name = "private"
url = "https://my-private-index.example.com/simple"
explicit = true
```

### Commonly Used Settings

| Setting | Purpose |
|---|---|
| `python` | Force specific Python version |
| `default-groups` | Groups included by default |
| `managed` | Enable/disable auto sync |
| `index-url` | Override primary PyPI index |
| `extra-index-url` | Additional indexes to search |
| `dev-dependencies` | Legacy dev deps (prefer `dependency-groups`) |
| `conflicts` | Declare incompatible extras/groups |

---

## Project Packaging vs. Virtual Projects

### Packaged Projects (default for libraries)

Includes a `[build-system]` in `pyproject.toml`. The project itself is installed as a package:

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

Common build backends: `hatchling`, `setuptools`, `flit-core`, `pdm-backend`, `maturin` (for Rust extensions).

### Virtual Projects (applications, scripts)

Omit `[build-system]`. The project's dependencies are installed but the project itself is not:

```toml
[project]
name = "my-app"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["flask>=3.0"]
# No [build-system] — project is not packaged
```

uv detects the absence of a build system and treats the project as a virtual project automatically.

### Explicit Packaging Toggle

```toml
[tool.uv]
package = false   # Force virtual (no install of the project itself)
package = true    # Force packaged (install the project as a package)
```

---

## pylock.toml and Export

`uv.lock` is uv-specific. For interoperability, export to standard formats:

```bash
# Export to requirements.txt (pip-compatible)
uv export -o requirements.txt

# Export to pylock.toml (PEP 751 standard)
uv export -o pylock.toml

# Export without dev dependencies
uv export --no-dev -o requirements.txt

# Export specific groups
uv export --group test -o requirements-test.txt
```

Use `requirements.txt` export for Docker builds, legacy CI pipelines, or tools that do not support `uv.lock`.

### Docker Pattern

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --no-dev --frozen

COPY . .
CMD ["uv", "run", "python", "-m", "my_project"]
```

Use `--frozen` in production to prevent any lockfile updates during install.
