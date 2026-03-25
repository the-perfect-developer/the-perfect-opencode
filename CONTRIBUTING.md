# Contributing to The Perfect OpenCode

Thank you for your interest in contributing! This document provides guidelines and setup instructions for contributors.

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/the-perfect-developer/the-perfect-opencode.git
cd the-perfect-opencode
```

### 2. Install Git Hooks

Set up git hooks for automatic code quality checks:

```bash
./scripts/setup-hooks.sh
```

This configures git to use hooks from the `.githooks/` directory.

## Git Hooks

This repository uses git hooks to maintain code quality:

### Pre-commit Hooks

The pre-commit orchestrator (`.githooks/pre-commit`) runs 4 validation hooks in sequence:

| Hook | Purpose |
|---|---|
| `10-validate-bash.sh` | Syntax-checks staged `.sh` files with `bash -n` |
| `20-validate-skills.sh` | Validates SKILL.md frontmatter for staged skill files |
| `30-validate-python-ruff.sh` | Runs Ruff lint + format check on staged Python files |
| `40-validate-eslint.sh` | Runs ESLint on staged JS/TS files (only activates if a root `package.json` exists) |

**Example output**:
```
[10-validate-bash] Validating bash script syntax...
  ✓ install.sh
[20-validate-skills] Validating SKILL.md files...
  ✓ .opencode/skills/python/SKILL.md
[30-validate-python-ruff] Running Ruff...
  ✓ No lint errors
[40-validate-eslint] Running ESLint...
  ✓ No lint errors
All hooks passed.
```

## CI/CD

### GitHub Actions Workflows

| Workflow | Trigger | Action |
|---|---|---|
| `validate-bash.yml` | PR/push to `main` | `bash -n` all `.sh` files |
| `validate-skills.yml` | PR/push to `main` | Validate all `SKILL.md` frontmatter |
| `generate-catalog.yml` | Push to `main` or `develop` | Auto-regenerate `opencode-catalog.json` |
| `generate-tools-docs.yml` | Push to `main` or `develop` (path-filtered) | Auto-regenerate `docs/tools-reference.md` |

> **Note**: `opencode-catalog.json` and `docs/tools-reference.md` are auto-generated — do not edit them manually.

## Code Quality Standards

### Bash Scripts

All bash scripts must:
1. Have valid syntax (verified by `bash -n`)
2. Include proper shebang (`#!/bin/bash`)
3. Be executable (`chmod +x`)
4. Follow consistent formatting

### Python

Python code is enforced by [Ruff](https://docs.astral.sh/ruff/) (lint + format), configured in `pyproject.toml`.

```bash
ruff check .               # lint
ruff check --fix .         # lint + auto-fix
ruff format .              # format
ruff format --check .      # format check (CI mode)
```

### JavaScript / TypeScript

JS/TS files in consumer projects are enforced by ESLint. The `40-validate-eslint.sh` hook only activates when a root `package.json` is present.

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Ensure all git hooks pass
5. Commit your changes following [Conventional Commits](https://www.conventionalcommits.org/) (`git commit -m 'feat: add amazing feature'`)
   All commits must follow the Conventional Commits spec (`feat`, `fix`, `docs`, `refactor`, `chore`, etc.)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Pull Request Guidelines

- Ensure all CI checks pass
- Provide clear description of changes
- Reference any related issues
- Keep changes focused and atomic

## Questions?

Feel free to open an issue for:
- Bug reports
- Feature requests
- Documentation improvements
- General questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
