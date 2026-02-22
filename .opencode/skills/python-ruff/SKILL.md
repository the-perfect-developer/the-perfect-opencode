---
name: python-ruff
description: This skill should be used when the user asks to "configure ruff", "set up ruff linting", "use ruff formatter", "replace flake8 with ruff", or needs guidance on Python code quality with Ruff linting and formatting best practices.
---

# Python Ruff — Linting and Formatting

Ruff is an extremely fast Python linter and code formatter written in Rust. It replaces Flake8, Black, isort, pydocstyle, pyupgrade, and autoflake with a single unified tool that runs 10–100x faster than any of them individually. Ruff supports over 800 built-in rules and provides automatic fix capabilities for many violations.

## Installation

Install Ruff via pip, uv, or as a development dependency:

```bash
pip install ruff
uv add --dev ruff
```

## Core Commands

```bash
ruff check                    # Lint all files in current directory
ruff check --fix              # Lint and auto-fix safe violations
ruff check --unsafe-fixes     # Show unsafe fixes (review before applying)
ruff check --fix --unsafe-fixes  # Apply all fixes including unsafe ones
ruff check --watch            # Re-lint on file changes
ruff format                   # Format all files in current directory
ruff format --check           # Check formatting without writing changes
ruff format --diff            # Show formatting diff without writing
```

Run both linting (with import sorting) and formatting in sequence:

```bash
ruff check --select I --fix   # Sort imports first
ruff format                   # Then format
```

## Configuration

Ruff reads from `pyproject.toml`, `ruff.toml`, or `.ruff.toml`. All three support the same schema; `ruff.toml` and `.ruff.toml` omit the `[tool.ruff]` prefix.

### Recommended Starter Configuration

```toml
[tool.ruff]
target-version = "py312"
line-length = 88

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "F",    # Pyflakes
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "I",    # isort
]
ignore = ["E501"]  # line-too-long (handled by formatter)

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
docstring-code-format = true
```

See `references/configuration-guide.md` for the full configuration reference.

## Rule Selection Best Practices

Rule codes follow the pattern `PREFIX + digits` (e.g., `F401` = Pyflakes unused import, `E711` = pycodestyle comparison to None).

**Start small, then expand:**

```toml
# Step 1: Minimal (safe baseline)
select = ["E4", "E7", "E9", "F"]

# Step 2: Recommended expansion
select = ["E", "F", "UP", "B", "SIM", "I"]

# Step 3: Strict (with targeted ignores)
select = ["ALL"]
ignore = ["D", "ANN", "COM812", "ISC001"]
```

**Key rule prefixes:**

| Prefix | Source             | Purpose                        |
|--------|--------------------|--------------------------------|
| `E/W`  | pycodestyle        | Style errors and warnings      |
| `F`    | Pyflakes           | Logical errors, unused imports |
| `B`    | flake8-bugbear     | Likely bugs and design issues  |
| `UP`   | pyupgrade          | Upgrade to modern Python syntax|
| `SIM`  | flake8-simplify    | Code simplification            |
| `I`    | isort              | Import sorting                 |
| `N`    | pep8-naming        | Naming convention checks       |
| `D`    | pydocstyle         | Docstring conventions          |
| `ANN`  | flake8-annotations | Type annotation enforcement    |
| `S`    | flake8-bandit      | Security checks                |
| `RUF`  | Ruff-native        | Ruff-specific rules            |

Use `lint.select` (not `lint.extend-select`) to make rule sets explicit. Avoid enabling `ALL` without carefully curating an `ignore` list, as it enables new rules on every Ruff upgrade.

See `references/rule-categories.md` for detailed rule guidance and common ignores.

## Automatic Fixes

Ruff distinguishes between **safe** and **unsafe** fixes:

- **Safe fixes** preserve code behavior exactly — applied by default with `--fix`
- **Unsafe fixes** may change runtime behavior (e.g., exception types, removed comments) — opt-in with `--unsafe-fixes`

Promote or demote fix safety per rule:

```toml
[tool.ruff.lint]
extend-safe-fixes = ["UP"]    # Treat pyupgrade fixes as safe
extend-unsafe-fixes = ["B"]   # Require explicit opt-in for bugbear fixes
```

Disable auto-fix for specific rules while keeping them as violations:

```toml
[tool.ruff.lint]
fixable = ["ALL"]
unfixable = ["F401"]  # Flag unused imports but don't auto-remove them
```

## Error Suppression

### Line-level suppression

```python
import os  # noqa: F401
x = 1  # noqa: E741, F841   # suppress multiple rules
y = 1  # noqa                # suppress all (avoid — too broad)
```

### Block-level suppression (preferred over blanket noqa)

```python
# ruff: disable[E501]
LONG_CONSTANT_1 = "Lorem ipsum dolor sit amet, consectetur adipiscing..."
LONG_CONSTANT_2 = "Lorem ipsum dolor sit amet, consectetur adipiscing..."
# ruff: enable[E501]
```

### File-level suppression

```python
# ruff: noqa: F841      # suppress specific rule for entire file
# ruff: noqa            # suppress all (avoid — use per-file-ignores instead)
```

### Per-file ignores in config (preferred)

```toml
[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]          # re-exports are intentional
"tests/**/*.py" = ["S101", "ANN"] # asserts and no annotations in tests
"scripts/**/*.py" = ["T20"]       # print() allowed in scripts
```

### Detecting unused suppressions

```bash
ruff check --extend-select RUF100        # flag stale noqa comments
ruff check --extend-select RUF100 --fix  # auto-remove stale noqa
```

## Formatter Configuration

The Ruff formatter is a drop-in replacement for Black. Key options:

```toml
[tool.ruff.format]
quote-style = "double"            # "double" | "single" | "preserve"
indent-style = "space"            # "space" | "tab"
line-ending = "auto"              # "auto" | "lf" | "crlf" | "native"
skip-magic-trailing-comma = false # respect trailing commas (like Black)
docstring-code-format = true      # format code examples in docstrings
```

### Suppressing formatter

```python
# fmt: off
matrix = [1,0,0,
          0,1,0,
          0,0,1]
# fmt: on

result = some_call()  # fmt: skip
```

### Rules incompatible with the formatter

Disable these rules to avoid conflicts when using `ruff format`:

```toml
[tool.ruff.lint]
ignore = [
    "W191",   # tab-indentation
    "E111",   # indentation-with-invalid-multiple
    "COM812", # missing-trailing-comma
    "ISC002", # multi-line-implicit-string-concatenation
    "Q000",   # bad-quotes-inline-string
    "Q001",   # bad-quotes-multiline-string
    "Q002",   # bad-quotes-docstring
]
```

## CI and Pre-commit Integration

### GitHub Actions

```yaml
- name: Lint and format check
  run: |
    ruff check .
    ruff format --check .
```

### pre-commit hooks

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

### Migrating an existing codebase

Auto-add `noqa` directives to all current violations, then clean up incrementally:

```bash
ruff check --add-noqa .    # adds noqa to all failing lines
ruff check --extend-select RUF100 --fix .  # remove stale noqa over time
```

## Quick Reference

| Task                              | Command                                      |
|-----------------------------------|----------------------------------------------|
| Lint current directory            | `ruff check`                                 |
| Lint and fix safe violations      | `ruff check --fix`                           |
| Format current directory          | `ruff format`                                |
| Check formatting (CI mode)        | `ruff format --check`                        |
| Sort imports only                 | `ruff check --select I --fix`                |
| Explain a rule                    | `ruff rule F401`                             |
| List all rules                    | `ruff linter`                                |
| Show active config for a file     | `ruff check --show-settings <file.py>`       |
| Flag unused noqa comments         | `ruff check --extend-select RUF100`          |

## Additional Resources

### Reference Files

- **`references/rule-categories.md`** — Detailed rule prefixes, common ignores, and per-category guidance
- **`references/configuration-guide.md`** — Full configuration options for linter and formatter

### Example Files

- **`examples/pyproject.toml`** — Production-ready pyproject.toml configuration
- **`examples/ruff.toml`** — Standalone ruff.toml configuration (monorepo root)
- **`examples/pre-commit-config.yaml`** — pre-commit hooks configuration
