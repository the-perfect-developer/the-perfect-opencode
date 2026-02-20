# Contributing to OpenCode Base Collection

Thank you for your interest in contributing! This document provides guidelines and setup instructions for contributors.

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/the-perfect-developer/opencode-base-collection.git
cd opencode-base-collection
```

### 2. Install Git Hooks

Set up git hooks for automatic code quality checks:

```bash
./scripts/setup-hooks.sh
```

This configures git to use hooks from the `.githooks/` directory.

## Git Hooks

This repository uses git hooks to maintain code quality:

### Pre-commit Hook

**Purpose**: Automatically validates bash script syntax before commits

**Details**:
- Location: `.githooks/pre-commit` (shared via version control)
- Validates all staged `.sh` files using `bash -n`
- Prevents commits with syntax errors
- Automatically runs when you execute `git commit`

**Example output**:
```
🔍 Validating bash script syntax...
  Checking: install.sh
  Checking: setup-hooks.sh
✅ All bash scripts validated successfully
```

If validation fails:
```
🔍 Validating bash script syntax...
  Checking: bad-script.sh
bad-script.sh: line 3: unexpected EOF while looking for matching `"'
❌ Syntax error in: bad-script.sh

❌ Commit rejected: bash script syntax validation failed
   Fix the syntax errors above and try again
```

## CI/CD

### GitHub Actions

**Workflow**: `.github/workflows/validate-bash.yml`

**Triggers**:
- Pull requests to `main` branch
- Direct pushes to `main` branch

**Function**: Validates ALL `.sh` files in the repository

**Features**:
- Runs `bash -n` on every bash script
- Clear output with status indicators
- Job summaries for easy review
- Fails the workflow if any syntax errors are found

## Code Quality Standards

### Bash Scripts

All bash scripts must:
1. Have valid syntax (verified by `bash -n`)
2. Include proper shebang (`#!/bin/bash`)
3. Be executable (`chmod +x`)
4. Follow consistent formatting

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Ensure all git hooks pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
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
