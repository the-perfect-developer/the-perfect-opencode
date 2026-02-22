# Ruff Rule Categories Reference

## Table of Contents

1. [Rule Code Format](#rule-code-format)
2. [Core Rule Prefixes](#core-rule-prefixes)
3. [Per-Category Guidance](#per-category-guidance)
4. [Common Ignore Patterns](#common-ignore-patterns)
5. [Rule Conflicts to Know](#rule-conflicts-to-know)

---

## Rule Code Format

Each rule code consists of a 1–3 letter prefix followed by 3 digits:

```
F401   →  F (Pyflakes) + 401 (unused-import)
B006   →  B (flake8-bugbear) + 006 (mutable-argument-default)
UP007  →  UP (pyupgrade) + 007 (use-x-or-y-for-union)
```

Selectors accept full codes or prefixes:

```toml
select = ["F401"]  # only this one rule
select = ["F"]     # all Pyflakes rules
select = ["ALL"]   # everything (800+ rules)
```

---

## Core Rule Prefixes

### E / W — pycodestyle

Style errors (`E`) and warnings (`W`). Based on PEP 8.

```toml
# Typical subset (safe with formatter):
select = ["E4", "E7", "E9"]
# E4xx: import errors
# E7xx: statement errors (comparison to None/True/False)
# E9xx: syntax and runtime errors
```

Avoid `E1xx`, `E2xx`, `E3xx`, `W1xx`, `W2xx`, `W3xx`, `W5xx` — these overlap with the formatter.

### F — Pyflakes

Logical correctness: unused imports, undefined names, redefined variables.

```toml
select = ["F"]
ignore = [
    "F401",  # unused-import — use per-file-ignores for __init__.py instead
    "F811",  # redefinition-of-unused-name — common in overloaded functions
]
```

High-value rules enabled by `F`:
- `F401` — unused import
- `F811` — redefinition of unused name
- `F841` — local variable assigned but never used
- `F821` — undefined name

### B — flake8-bugbear

Catches likely bugs and opinionated design issues beyond PEP 8.

```toml
select = ["B"]
ignore = [
    "B008",  # do-not-perform-function-calls-in-default-arguments (conflicts with FastAPI/Depends)
    "B904",  # raise-without-from-inside-except (enforce raise from inside except)
]
```

High-value rules:
- `B006` — mutable default argument (e.g., `def f(x=[])`)
- `B007` — loop variable not used in loop body
- `B009` — getattr with constant (use attribute access)
- `B023` — function definition in loop without binding
- `B904` — raise without `from` inside `except`

### UP — pyupgrade

Upgrades Python syntax to modern equivalents. Always pair with `target-version`.

```toml
[tool.ruff]
target-version = "py312"

[tool.ruff.lint]
select = ["UP"]
```

Key transformations:
- `UP006` — `typing.List` → `list` (Python 3.9+)
- `UP007` — `Optional[X]` → `X | None` (Python 3.10+)
- `UP035` — deprecated `typing` imports → `collections.abc`
- `UP038` — `isinstance(x, (A, B))` → `isinstance(x, A | B)` (Python 3.10+)

### SIM — flake8-simplify

Simplifies overly complex constructs.

```toml
select = ["SIM"]
ignore = [
    "SIM108",  # ternary operator (sometimes explicit if/else is clearer)
    "SIM117",  # combine nested with (sometimes nested is more readable)
]
```

Key rules:
- `SIM101` — duplicate isinstance check → union
- `SIM105` — `try/except/pass` → `contextlib.suppress`
- `SIM115` — open file without context manager
- `SIM118` — `key in dict.keys()` → `key in dict`

### I — isort

Import sorting. Fully compatible with the Ruff formatter.

```toml
select = ["I"]
# Plugin config:
[tool.ruff.lint.isort]
known-first-party = ["mypackage"]
known-third-party = ["requests", "pydantic"]
```

Avoid these isort settings when using `ruff format` (they conflict):
- `force-single-line`
- `force-wrap-aliases`
- `lines-after-imports`
- `lines-between-types`
- `split-on-trailing-comma`

### N — pep8-naming

Naming convention enforcement.

```toml
select = ["N"]
ignore = [
    "N802",  # function name should be lowercase (conflicts with test mocks)
    "N806",  # variable in function should be lowercase (sometimes needed for constants)
    "N812",  # lowercase imported as non-lowercase (common for `import numpy as np`)
]
```

### D — pydocstyle

Docstring conventions. Choose one style and stick to it.

```toml
select = ["D"]
ignore = [
    "D100", "D101", "D102", "D103",  # missing docstrings (too strict for many projects)
    "D203",  # one-blank-line-before-class — conflicts with D211
    "D213",  # multi-line-summary-second-line — conflicts with D212
]

[tool.ruff.lint.pydocstyle]
convention = "google"  # "google" | "numpy" | "pep257"
```

Use `convention = "google"` instead of manual rule selection — it activates the right subset automatically.

### ANN — flake8-annotations

Type annotation enforcement.

```toml
select = ["ANN"]
ignore = [
    "ANN101", "ANN102",  # missing type for self/cls (deprecated in newer ruff)
    "ANN401",            # typed as Any (sometimes unavoidable)
]
```

Consider enabling only for public APIs:

```toml
[tool.ruff.lint.per-file-ignores]
"tests/**" = ["ANN"]
```

### S — flake8-bandit

Security checks. High false-positive rate — use with curated ignores.

```toml
select = ["S"]
ignore = [
    "S101",  # assert used (needed in tests)
    "S311",  # random not cryptographically secure (fine for non-security uses)
    "S603",  # subprocess call — acceptable when input is controlled
    "S607",  # partial executable path — acceptable in dev scripts
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "S105", "S106"]
```

### RUF — Ruff-native Rules

Ruff-specific rules not available in any upstream tool.

```toml
select = ["RUF"]
```

Key rules:
- `RUF005` — collection literal concatenation (use spread instead)
- `RUF010` — explicit conversion flag in f-string
- `RUF013` — implicit Optional (use `X | None` explicitly)
- `RUF100` — unused noqa comment (always enable this)
- `RUF200` — invalid pyproject.toml

### C — McCabe / Convention

- `C9xx` — McCabe complexity (`C901`)
- `C4xx` — flake8-comprehensions (unnecessary comprehensions)

```toml
select = ["C4", "C9"]
[tool.ruff.lint.mccabe]
max-complexity = 10
```

---

## Per-Category Guidance

### Strict project setup

For mature projects wanting maximum quality enforcement:

```toml
[tool.ruff.lint]
select = ["ALL"]
ignore = [
    # Formatter conflicts
    "COM812", "ISC001",
    # Docstring style conflict (choose one pair)
    "D203", "D213",
    # Too opinionated or context-dependent
    "ANN101", "ANN102",  # self/cls annotations
    "D100", "D101",      # missing public module/class docstrings
    "FIX002",            # line-contains-todo
    "TD002", "TD003",    # missing TODO author/issue
    "ERA001",            # commented-out code (too noisy)
]
```

### Library / package setup

```toml
[tool.ruff.lint]
select = ["E", "F", "UP", "B", "SIM", "I", "N", "D", "ANN", "RUF"]
ignore = ["D100", "D104", "ANN401"]
[tool.ruff.lint.pydocstyle]
convention = "google"
```

### Application / service setup

```toml
[tool.ruff.lint]
select = ["E", "F", "UP", "B", "SIM", "I", "RUF", "S"]
ignore = ["S101", "S603"]
```

---

## Common Ignore Patterns

### In configuration

```toml
[tool.ruff.lint.per-file-ignores]
# Test files
"tests/**/*.py" = [
    "S101",   # assert statements are fine in tests
    "ANN",    # no type annotations required in tests
    "D",      # no docstrings required in tests
    "PLR2004",# magic value comparisons OK in tests
]
# Init files (re-exports)
"__init__.py" = ["F401"]
# Migration files
"migrations/**" = ["E501", "RUF"]
# Scripts
"scripts/**/*.py" = ["T20", "S"]
```

### Inline suppression best practices

Prefer specific codes over blanket `# noqa`:

```python
# Good — specific and self-documenting
import os  # noqa: F401  — re-exported for downstream use

# Bad — suppresses everything, hides real issues
import os  # noqa
```

---

## Rule Conflicts to Know

### D203 vs D211

`D203`: one blank line before class docstring  
`D211`: no blank lines before class docstring  
These are mutually exclusive. Disable `D203` (use `D211`, the more common convention).

### D212 vs D213

`D212`: multi-line summary on first line  
`D213`: multi-line summary on second line  
Disable `D213` if using Google/NumPy conventions (they prefer `D212`).

### Formatter-incompatible rules

When using `ruff format`, disable these lint rules to prevent conflicts:

| Rule   | Code   | Reason                              |
|--------|--------|-------------------------------------|
| W191   | tab-indentation | formatter controls indentation |
| E111   | indentation-with-invalid-multiple | same |
| COM812 | missing-trailing-comma | formatter controls trailing commas |
| ISC002 | multi-line-implicit-str-concat | formatter controls this |
| Q000–Q004 | bad-quotes-* | formatter controls quote style |

Check for conflicts at any time:

```bash
ruff format --check .   # will warn about incompatible rules
```
