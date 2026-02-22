---
name: python-uv
description: This skill should be used when the user asks to "set up a Python project with uv", "manage dependencies with uv", "create a uv project", "use uv for Python package management", or needs guidance on uv workflows, pyproject.toml configuration, lockfiles, and development dependency groups.
---

# Python UV Project Management

Provides workflows and best practices for managing Python projects using uv — Astral's fast Python package and project manager.

## Project Initialization

Create a new project with `uv init`:

```bash
# Named project in new directory
uv init my-project
cd my-project

# Initialize in current directory
uv init
```

Generated structure:

```
my-project/
├── .gitignore
├── .python-version
├── README.md
├── main.py
└── pyproject.toml
```

After the first `uv run`, `uv sync`, or `uv lock`, uv creates:

```
my-project/
├── .venv/
├── .python-version
├── README.md
├── main.py
├── pyproject.toml
└── uv.lock
```

Run the project immediately after init:

```bash
uv run main.py
```

uv auto-creates and syncs the virtual environment on every `uv run` invocation.

## Core File Roles

| File | Purpose | Commit? |
|---|---|---|
| `pyproject.toml` | Broad requirements, project metadata | Yes |
| `uv.lock` | Exact resolved versions, cross-platform | Yes |
| `.python-version` | Default Python version for the project | Yes |
| `.venv/` | Isolated virtual environment | No |

**Critical rule**: Commit `uv.lock` to version control. It guarantees reproducible installs across machines and CI environments. Never edit it manually.

## Managing Dependencies

### Runtime Dependencies

```bash
# Add with automatic version constraint
uv add requests

# Add with explicit version constraint
uv add 'requests>=2.31.0'

# Add with extras
uv add 'pandas[excel,plot]'

# Add platform-specific dependency
uv add "jax; sys_platform == 'linux'"
```

### Development Dependencies

Separate dev dependencies from published requirements using dependency groups:

```bash
# Add to the default dev group (not published to PyPI)
uv add --dev pytest ruff mypy

# Add to named groups for fine-grained control
uv add --group lint ruff
uv add --group test pytest pytest-cov
uv add --group docs mkdocs
```

Resulting `pyproject.toml`:

```toml
[dependency-groups]
dev = ["pytest>=8.1.1,<9"]
lint = ["ruff>=0.4.0"]
test = ["pytest", "pytest-cov"]
```

Groups can nest to avoid duplication:

```toml
[dependency-groups]
lint = ["ruff"]
test = ["pytest"]
dev = [
  {include-group = "lint"},
  {include-group = "test"},
]
```

### Removing and Upgrading

```bash
# Remove a dependency
uv remove requests

# Upgrade a specific package to latest compatible version
uv lock --upgrade-package requests

# Upgrade all packages
uv lock --upgrade
```

## Running Commands

Always use `uv run` — it ensures the environment is synced before execution:

```bash
# Run a Python script
uv run main.py

# Run a tool from the environment
uv add flask
uv run -- flask run -p 3000

# Run with a one-off extra dependency (not added to project)
uv run --with rich python -c "import rich; rich.print('[bold]Hello[/bold]')"

# Run only specific dependency groups
uv run --no-default-groups --group test pytest
```

Alternatively, sync and activate manually when needed (e.g., interactive shells):

```bash
# macOS/Linux
uv sync
source .venv/bin/activate

# Windows
uv sync
.venv\Scripts\activate
```

**Do not** use `uv pip install` for project dependencies — use `uv add` instead. Direct pip manipulation bypasses the lockfile and breaks reproducibility.

## Dependency Sources

Override where packages are fetched from during development using `tool.uv.sources`:

```bash
# From a local path (editable)
uv add --editable ../my-lib

# From a Git repository
uv add git+https://github.com/encode/httpx

# Pin to a specific Git tag
uv add git+https://github.com/encode/httpx --tag 0.27.0

# From a custom index
uv add torch --index pytorch=https://download.pytorch.org/whl/cpu
```

Sources are a uv-only development feature. Use `--no-sources` to validate that published metadata is self-contained:

```bash
uv lock --no-sources
uv build --no-sources
```

## Syncing and Locking

```bash
# Sync environment to lockfile (installs missing, removes extra)
uv sync

# Sync including all dependency groups
uv sync --all-groups

# Sync only specific groups
uv sync --group test

# Regenerate lockfile without syncing
uv lock

# Check if lockfile is up-to-date (for CI)
uv lock --check
```

## Building and Viewing Version

```bash
# Build source distribution and wheel
uv build

# Check built artifacts
ls dist/
# my-project-0.1.0-py3-none-any.whl
# my-project-0.1.0.tar.gz

# View current package version
uv version
uv version --short        # 0.1.0 only
uv version --output-format json
```

## Best Practices

**Lockfile hygiene**
- Commit `uv.lock`; never edit it manually
- Run `uv lock --check` in CI to detect uncommitted lockfile drift
- Use `uv lock --upgrade-package <name>` for targeted upgrades, not `--upgrade` carelessly

**Dependency discipline**
- Use `--dev` / `--group` for all non-runtime dependencies (linters, formatters, test runners, type checkers)
- Never use `uv pip install` directly in a project — always `uv add`
- Set `requires-python` in `pyproject.toml` to lock down supported versions

**Environment hygiene**
- Never commit `.venv/`; the generated `.gitignore` excludes it by default
- Use `uv run` rather than activating the venv manually in scripts and CI
- For one-off tools, prefer `uvx <tool>` over installing into the project environment

**Publishing safety**
- Run `uv build --no-sources` before publishing to validate published metadata is correct without `tool.uv.sources` overrides

**pyproject.toml example** (library pattern):

```toml
[project]
name = "my-lib"
version = "0.1.0"
description = "A short description"
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27.0",
]

[project.optional-dependencies]
network = ["aiohttp>=3.9"]

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
```

## Quick Reference

| Task | Command |
|---|---|
| Create project | `uv init <name>` |
| Run script | `uv run <file.py>` |
| Add dependency | `uv add <package>` |
| Add dev dependency | `uv add --dev <package>` |
| Add to named group | `uv add --group <group> <package>` |
| Remove dependency | `uv remove <package>` |
| Upgrade package | `uv lock --upgrade-package <name>` |
| Sync environment | `uv sync` |
| Rebuild lockfile | `uv lock` |
| Build distributions | `uv build` |
| Check version | `uv version` |
| Run tool one-off | `uv run --with <pkg> python ...` |
| Simulate no sources | `uv lock --no-sources` |

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/dependency-management.md`** — Advanced dependency configuration: optional extras, platform markers, multiple sources, editable installs, and dependency specifier syntax
- **`references/project-structure.md`** — Deep dive on `pyproject.toml`, `uv.lock`, `.python-version`, workspace layout, and configuration options
