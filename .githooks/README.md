# Git Hooks — Modular Architecture

This directory contains modular pre-commit hooks for validating code before commits.

## Structure

```
.githooks/
├── pre-commit          # Main orchestrator script
├── hooks.d/            # Individual validation hooks
│   ├── 10-validate-bash.sh           # Validates bash script syntax
│   ├── 20-validate-skills.sh         # Validates SKILL.md files
│   ├── 30-validate-python-ruff.sh    # Validates Python code with Ruff
│   └── 40-validate-eslint.sh         # Validates JS/TS code with ESLint
└── README.md           # This file
```

## How It Works

1. **Git runs** `.githooks/pre-commit` when you attempt to commit
2. **Orchestrator** finds all executable scripts in `hooks.d/` and runs them in numerical order
3. **Each hook** performs its validation and exits with 0 (pass) or non-zero (fail)
4. **If any hook fails**, the commit is rejected

## Current Validation Hooks

### 10-validate-bash.sh
- **Purpose:** Validates bash script syntax
- **Triggers on:** Any staged `.sh` files
- **What it does:** Runs `bash -n` to check syntax without executing
- **How to test:** `./.githooks/hooks.d/10-validate-bash.sh`

### 20-validate-skills.sh
- **Purpose:** Validates SKILL.md files structure and content
- **Triggers on:** Any staged `SKILL.md` files
- **What it does:** Runs the skill validation script at `.opencode/skills/skill-creation/scripts/validate-skill.sh`
- **How to test:** `./.githooks/hooks.d/20-validate-skills.sh`

### 30-validate-python-ruff.sh
- **Purpose:** Validates Python code quality
- **Triggers on:** Any staged `.py` files
- **What it does:** Runs Ruff lint and format check on staged Python files
- **How to test:** `./.githooks/hooks.d/30-validate-python-ruff.sh`

### 40-validate-eslint.sh
- **Purpose:** Validates JavaScript and TypeScript code quality
- **Triggers on:** Any staged `.js`, `.ts`, `.jsx`, `.tsx` files
- **Activation condition:** Only activates if a root `package.json` exists
- **What it does:** Runs ESLint on staged JS/TS files
- **How to test:** `./.githooks/hooks.d/40-validate-eslint.sh`

## Adding a New Hook

1. **Create a new script** in `hooks.d/` with a numbered name:
   ```bash
   touch .githooks/hooks.d/50-my-new-validation.sh
   chmod +x .githooks/hooks.d/50-my-new-validation.sh
   ```

2. **Use this template:**
   ```bash
   #!/bin/bash

   # Pre-commit hook: Description of what this validates

   set -e

   echo "Running my validation..."

   # Get staged files of interest
   STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep 'pattern' || true)

   if [ -z "$STAGED_FILES" ]; then
       echo "No files to validate"
       exit 0
   fi

   # Perform your validation
   # ... your validation logic here ...

   echo "Validation passed"
   exit 0
   ```

3. **Test your hook independently:**
   ```bash
   ./.githooks/hooks.d/50-my-new-validation.sh
   ```

4. **Test the full pre-commit flow:**
   ```bash
   ./.githooks/pre-commit
   ```

## Naming Convention

Hook files use the pattern: `<NN>-<description>.sh`

**Number increments of 10** allow insertion of new hooks between existing ones:
- `10-validate-bash.sh`
- `20-validate-skills.sh`
- `30-validate-python-ruff.sh`
- `40-validate-eslint.sh`
- `50-your-new-hook.sh` ← New hook

If you need to insert between existing hooks, use an intermediate number (e.g., `15-inserted-hook.sh`).

## Temporarily Disabling a Hook

### Option 1: Remove execute permission
```bash
chmod -x .githooks/hooks.d/20-validate-skills.sh
```

### Option 2: Rename to add .disabled extension
```bash
mv .githooks/hooks.d/20-validate-skills.sh \
   .githooks/hooks.d/20-validate-skills.sh.disabled
```

### Option 3: Skip all hooks for one commit (use sparingly!)
```bash
git commit --no-verify -m "Your message"
```

## Re-enabling a Hook

```bash
# If you removed execute permission:
chmod +x .githooks/hooks.d/20-validate-skills.sh

# If you renamed it:
mv .githooks/hooks.d/20-validate-skills.sh.disabled \
   .githooks/hooks.d/20-validate-skills.sh
```

## Testing Individual Hooks

You can run any hook independently for testing:

```bash
# Test bash validation
./.githooks/hooks.d/10-validate-bash.sh

# Test skill validation
./.githooks/hooks.d/20-validate-skills.sh

# Test Python validation
./.githooks/hooks.d/30-validate-python-ruff.sh

# Test JS/TS validation
./.githooks/hooks.d/40-validate-eslint.sh

# Test all hooks (same as what git runs)
./.githooks/pre-commit
```

## Troubleshooting

### Hooks not running?
Check your git config:
```bash
git config core.hookspath
```
Should output: `.githooks`

If not set:
```bash
git config core.hookspath .githooks
```

### Hook fails but you don't know why?
Add debug output to the specific hook script. Each hook is just a bash script that you can edit and debug.

### Want to see which hooks will run?
```bash
find .githooks/hooks.d -type f -executable | sort
```

## Best Practices

1. **Keep hooks fast** — They run on every commit
2. **Exit early** — If there's nothing to validate, exit with 0 immediately
3. **Clear output** — Use clear status messages
4. **Test independently** — Always test your hook script directly before relying on it in commits
5. **Handle missing dependencies gracefully** — If an external tool isn't available, warn and skip (don't fail)

## Git Hook Configuration

This repository uses a custom git hooks directory:
```bash
git config core.hookspath .githooks
```

This allows the hooks to be version-controlled and shared across the team.