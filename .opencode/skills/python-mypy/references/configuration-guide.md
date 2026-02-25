# mypy Configuration Guide

Complete reference for configuring mypy via `pyproject.toml` and per-module overrides.

## Table of Contents

- [Configuration File Precedence](#configuration-file-precedence)
- [Minimal Configurations](#minimal-configurations)
- [Strict Configuration](#strict-configuration)
- [Incremental Migration Config](#incremental-migration-config)
- [Per-Module Overrides](#per-module-overrides)
- [Plugin Configuration](#plugin-configuration)
- [Key Options Reference](#key-options-reference)

## Configuration File Precedence

Mypy discovers configuration in this order (highest to lowest precedence):

1. `--config-file` CLI flag
2. `mypy.ini` or `.mypy.ini` in the project root
3. `pyproject.toml` (section `[tool.mypy]`)
4. `setup.cfg` (section `[mypy]`)
5. `~/.config/mypy/config` (user-global)

Always prefer `pyproject.toml` for new projects — it consolidates all tool config in one place.

## Minimal Configurations

### New Greenfield Project

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
warn_unused_ignores = true
disallow_untyped_defs = true
```

### Library / Package (published to PyPI)

```toml
[tool.mypy]
python_version = "3.9"        # match your minimum supported version
strict = true
warn_unused_ignores = true

# Expose public API types properly
implicit_reexport = false
```

### Script / CLI Tool

```toml
[tool.mypy]
python_version = "3.12"
strict = true
scripts_are_modules = true    # treat script files as modules
```

## Strict Configuration

Full `strict = true` equivalent (all flags it enables, listed explicitly for documentation):

```toml
[tool.mypy]
python_version = "3.12"

# Strict flag bundle (equivalent to strict = true, but explicit)
disallow_untyped_defs = true
disallow_incomplete_defs = true
disallow_untyped_decorators = true
disallow_any_generics = true
disallow_subclassing_any = true
warn_return_any = true
warn_unused_ignores = true
strict_equality = true
extra_checks = true
no_implicit_reexport = true

# Additional recommended settings
warn_unused_configs = true
warn_redundant_casts = true
warn_unreachable = true
```

Note: the exact flags bundled in `strict` may change across mypy releases. Using `strict = true` is safer than listing them individually.

## Incremental Migration Config

For a large existing codebase being progressively typed:

```toml
[tool.mypy]
python_version = "3.11"

# Start permissive
warn_unused_configs = true
warn_return_any = true
warn_unused_ignores = true

# Check unannotated bodies (catches bugs without requiring annotations)
check_untyped_defs = true

# Per-package strictness overrides — add packages as they get annotated
[[tool.mypy.overrides]]
module = "myapp.core.*"
disallow_untyped_defs = true
disallow_incomplete_defs = true

[[tool.mypy.overrides]]
module = "myapp.api.*"
disallow_untyped_defs = true

# Legacy packages — ignore for now
[[tool.mypy.overrides]]
module = "myapp.legacy.*"
ignore_errors = true

# Third-party libraries without stubs
[[tool.mypy.overrides]]
module = [
    "boto3.*",
    "botocore.*",
    "some_untyped_package.*",
]
ignore_missing_imports = true
```

## Per-Module Overrides

Per-module overrides allow fine-grained control. The `module` key supports glob patterns.

### Pattern Matching Rules

```toml
# Exact module
[[tool.mypy.overrides]]
module = "myapp.utils"
disallow_untyped_defs = true

# All submodules of a package
[[tool.mypy.overrides]]
module = "myapp.core.*"
strict = true

# Multiple modules in one block
[[tool.mypy.overrides]]
module = ["myapp.v1.*", "myapp.v2.*"]
disallow_untyped_defs = true

# Wildcard in the middle (unstructured)
[[tool.mypy.overrides]]
module = "myapp.*.migrations"
ignore_errors = true
```

### Suppressing Third-Party Imports

Never use global `ignore_missing_imports = true`. Always scope it:

```toml
[[tool.mypy.overrides]]
module = [
    "cv2",
    "PIL.*",
    "sklearn.*",
    "torch.*",
]
ignore_missing_imports = true
```

## Plugin Configuration

### Pydantic v2

```toml
[tool.mypy]
plugins = ["pydantic.mypy"]

[tool.pydantic-mypy]
init_forbid_extra = true
init_typed = true
warn_required_dynamic_aliases = true
```

### SQLAlchemy 2.x

```toml
[tool.mypy]
plugins = ["sqlalchemy.ext.mypy.plugin"]
```

### Django

```bash
pip install django-stubs
```

```toml
[tool.mypy]
plugins = ["mypy_django_plugin.main"]

[tool.django-stubs]
django_settings_module = "myproject.settings"
```

## Key Options Reference

### Strictness Options

| Option | Default | Effect |
|---|---|---|
| `strict` | `false` | Enable all optional checks |
| `disallow_untyped_defs` | `false` | Require annotations on all functions |
| `disallow_incomplete_defs` | `false` | Disallow partially annotated functions |
| `check_untyped_defs` | `false` | Type-check bodies of unannotated functions |
| `disallow_any_generics` | `false` | Require explicit type params on generics |
| `warn_return_any` | `false` | Warn when returning `Any` from typed function |
| `strict_equality` | `false` | Error on comparisons of non-overlapping types |

### Import Options

| Option | Default | Effect |
|---|---|---|
| `ignore_missing_imports` | `false` | Suppress unresolved import errors |
| `follow_untyped_imports` | `false` | Analyze unannotated installed packages |
| `no_implicit_reexport` | `false` | Require explicit re-export |

### Warning Options

| Option | Default | Effect |
|---|---|---|
| `warn_unused_ignores` | `false` | Flag stale `# type: ignore` comments |
| `warn_unused_configs` | `false` | Warn about unused config sections |
| `warn_redundant_casts` | `false` | Warn about `cast()` that changes nothing |
| `warn_unreachable` | `false` | Warn about unreachable code after narrowing |

### Error Code Control

Disable specific error codes that are not relevant to a project:

```toml
[tool.mypy]
disable_error_code = ["import-untyped"]

# Or enable codes not in strict
enable_error_code = ["redundant-expr", "possibly-undefined", "truthy-bool"]
```

Common error codes: `attr-defined`, `name-defined`, `call-arg`, `arg-type`, `return-value`, `assignment`, `index`, `union-attr`, `override`, `import-untyped`, `no-untyped-def`.

## Inline Configuration

Override config for specific lines or files using inline comments:

```python
# Suppress a specific error on one line (always add a reason comment)
x = untyped_result  # type: ignore[assignment]  # third-party returns Any

# Suppress all errors on a line (avoid — too broad)
x = untyped_result  # type: ignore

# File-level suppression via inline config (top of file)
# mypy: disable-error-code="import-untyped"
```

Use `# type: ignore` as a last resort. Prefer fixing the underlying type issue or using targeted per-module config overrides.
