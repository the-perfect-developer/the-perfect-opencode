# Ruff Configuration Guide

## Table of Contents

1. [Config File Options](#config-file-options)
2. [Top-level Settings](#top-level-settings)
3. [Linter Settings](#linter-settings)
4. [Formatter Settings](#formatter-settings)
5. [Config Discovery and Inheritance](#config-discovery-and-inheritance)
6. [Monorepo Patterns](#monorepo-patterns)
7. [Migration from Legacy Tools](#migration-from-legacy-tools)

---

## Config File Options

Ruff supports three config file formats, searched in this priority order within each directory:

| File            | Notes                                       |
|-----------------|---------------------------------------------|
| `.ruff.toml`    | Highest priority, Ruff-only project         |
| `ruff.toml`     | Middle priority, Ruff-only project          |
| `pyproject.toml`| Lowest priority, requires `[tool.ruff]` section |

All are equivalent in capability. Use `pyproject.toml` for unified project configuration; use `ruff.toml` or `.ruff.toml` for Ruff-only or when pyproject.toml is unavailable.

---

## Top-level Settings

```toml
[tool.ruff]
# Python version for syntax/rule compatibility
target-version = "py312"  # py37–py315

# Line length (affects both linter E501 and formatter)
line-length = 88           # default: 88 (same as Black)

# Indentation width
indent-width = 4           # default: 4

# Files/directories to exclude (extend default list)
extend-exclude = [
    "generated/",
    "vendor/",
    "*.pyi",
]

# Include additional file types
extend-include = ["*.md"]  # format Markdown code blocks (preview)

# Respect .gitignore (default: true)
respect-gitignore = true

# Force exclusions even for explicitly passed paths
force-exclude = false

# Source paths for import resolution
src = ["src", "tests"]

# Inherit from another config
extend = "../pyproject.toml"
```

---

## Linter Settings

```toml
[tool.ruff.lint]
# Rules to enable (explicit is better)
select = ["E", "F", "UP", "B", "SIM", "I"]

# Rules to disable (subset of selected)
ignore = ["E501"]

# Add rules on top of an inherited config
extend-select = ["RUF100"]

# Rules eligible for auto-fix (default: ALL)
fixable = ["ALL"]

# Rules excluded from auto-fix
unfixable = ["F401", "B"]

# Promote rules' fixes from unsafe to safe
extend-safe-fixes = ["UP"]

# Demote rules' fixes from safe to unsafe
extend-unsafe-fixes = ["B009"]

# Allow underscore-prefixed unused variables
dummy-variable-rgx = "^(_+|(_+[a-zA-Z0-9_]*[a-zA-Z0-9]+?))$"

# Per-file rule overrides
[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]
"tests/**/*.py" = ["S101", "ANN", "D"]
"scripts/**/*.py" = ["T20"]

# Enable unsafe fixes by default (opt-in)
# unsafe-fixes = true
```

### isort Plugin Config

```toml
[tool.ruff.lint.isort]
# Treat as first-party packages
known-first-party = ["mypackage", "mylib"]

# Force third-party placement
known-third-party = ["requests", "pydantic", "fastapi"]

# Number of blank lines between import sections
lines-between-sections = 1

# Split imports onto separate lines (avoid with ruff format)
# force-single-line = false   # keep default

# Combine import statements
combine-as-imports = false

# Order of import sections
section-order = [
    "future", "standard-library", "third-party",
    "first-party", "local-folder"
]
```

### McCabe Complexity

```toml
[tool.ruff.lint.mccabe]
max-complexity = 10  # default: 10
```

### pydocstyle Plugin Config

```toml
[tool.ruff.lint.pydocstyle]
# Convention auto-selects the right D rules
convention = "google"  # "google" | "numpy" | "pep257"
```

### flake8-annotations Plugin Config

```toml
[tool.ruff.lint.flake8-annotations]
allow-star-arg-any = true       # allow *args: Any
ignore-fully-untyped = true     # skip files with no annotations
suppress-none-returning = true  # don't require -> None
```

### flake8-bugbear Plugin Config

```toml
[tool.ruff.lint.flake8-bugbear]
# Functions allowed as default arguments
extend-immutable-calls = [
    "fastapi.Depends", "fastapi.Query", "fastapi.Header",
    "typer.Option", "typer.Argument",
]
```

### flake8-import-conventions

```toml
[tool.ruff.lint.flake8-import-conventions.aliases]
numpy = "np"
pandas = "pd"
matplotlib = "mpl"
"matplotlib.pyplot" = "plt"
```

---

## Formatter Settings

```toml
[tool.ruff.format]
# Quote style for strings
quote-style = "double"    # "double" | "single" | "preserve"

# Indentation style
indent-style = "space"    # "space" | "tab"

# Line ending
line-ending = "auto"      # "auto" | "lf" | "crlf" | "native"

# Respect trailing commas to keep expressions expanded
skip-magic-trailing-comma = false  # default: false (like Black)

# Format code examples in docstrings
docstring-code-format = true  # default: false (enable recommended)

# Line length for docstring code examples
docstring-code-line-length = "dynamic"  # or an integer

# Exclude file patterns from formatting
exclude = ["*.pyi"]  # example: don't format stub files
```

---

## Config Discovery and Inheritance

### File Discovery Rules

1. Ruff searches upward from each analyzed file for the nearest config
2. Uses `.ruff.toml` > `ruff.toml` > `pyproject.toml` (with `[tool.ruff]` section)
3. Falls back to user-level config at `~/.config/ruff/pyproject.toml`
4. Infers `target-version` from `requires-python` in `pyproject.toml` if unset

### Inheritance with `extend`

Ruff does **not** merge configs automatically (unlike ESLint). Use `extend` explicitly:

```toml
# packages/mylib/pyproject.toml
[tool.ruff]
extend = "../../pyproject.toml"   # inherit from monorepo root
line-length = 100                  # override just this setting

[tool.ruff.lint]
extend-ignore = ["D100"]          # add ignores on top of root config
```

### CLI Config Override

Pass ad-hoc overrides without modifying files:

```bash
# Override a specific setting
ruff check . --config "lint.per-file-ignores={'generated.py'=['ALL']}"

# Point to a different config file
ruff check . --config path/to/other/ruff.toml

# Ignore all config files
ruff check . --isolated
```

---

## Monorepo Patterns

### Root + package configs

```
monorepo/
├── pyproject.toml        ← root config (shared baseline)
├── packages/
│   ├── core/
│   │   └── pyproject.toml  ← extends root, stricter rules
│   └── scripts/
│       └── ruff.toml       ← extends root, relaxed rules
```

Root config (`pyproject.toml`):
```toml
[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "UP", "B", "I"]
```

Package config (`packages/core/pyproject.toml`):
```toml
[tool.ruff]
extend = "../../pyproject.toml"

[tool.ruff.lint]
extend-select = ["D", "ANN", "S"]
[tool.ruff.lint.pydocstyle]
convention = "google"
```

Scripts config (`packages/scripts/ruff.toml`):
```toml
extend = "../../pyproject.toml"
[lint]
extend-ignore = ["T20", "S603", "S607"]
```

---

## Migration from Legacy Tools

### From Flake8

1. Install Ruff: `pip install ruff`
2. Use `--add-noqa` to suppress existing violations while migrating:
   ```bash
   ruff check --add-noqa .
   ```
3. Map Flake8 plugins to Ruff rule prefixes:

| Flake8 Plugin         | Ruff Prefix |
|-----------------------|-------------|
| pyflakes              | F           |
| pycodestyle           | E, W        |
| flake8-bugbear        | B           |
| flake8-comprehensions | C4          |
| flake8-annotations    | ANN         |
| flake8-bandit         | S           |
| flake8-docstrings     | D           |
| flake8-simplify       | SIM         |
| flake8-import-order   | I           |

### From Black

The Ruff formatter is a drop-in replacement. Run:
```bash
ruff format .
```

Verify output is identical for existing Black-formatted files (>99.9% parity expected).

### From isort

Enable `I` rules and run:
```bash
ruff check --select I --fix .
```

Then add `I` to `select` in config.

### From pyupgrade

Enable `UP` rules with your target Python version:
```toml
[tool.ruff]
target-version = "py312"
[tool.ruff.lint]
select = ["UP"]
```

Run with `--fix` to apply modernizations.

### From autoflake

Enable relevant rules:
```toml
select = ["F401", "F811"]  # unused imports, redefined names
```

Apply with `ruff check --fix .`.
