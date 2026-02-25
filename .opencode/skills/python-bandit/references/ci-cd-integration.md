# Bandit CI/CD Integration Guide

Comprehensive guide for integrating Bandit into continuous integration and deployment pipelines.

## Table of Contents

- [Pre-commit Hook](#pre-commit-hook)
- [GitHub Actions](#github-actions)
- [Baseline Strategy](#baseline-strategy)
- [Adopting Bandit on Legacy Codebases](#adopting-bandit-on-legacy-codebases)
- [Enforcing Severity Thresholds](#enforcing-severity-thresholds)
- [Multi-format Reporting](#multi-format-reporting)

---

## Pre-commit Hook

The fastest way to enforce Bandit on every commit. Catches issues before they enter the repository.

### Setup

Install pre-commit:

```bash
pip install pre-commit
```

Add Bandit to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: '1.8.3'   # pin to a real release tag
    hooks:
      - id: bandit
```

Activate hooks:

```bash
pre-commit install
```

### With pyproject.toml Config

When using a `pyproject.toml` config file, pass it explicitly and add the `toml` extra:

```yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: '1.8.3'
    hooks:
      - id: bandit
        args: ["-c", "pyproject.toml"]
        additional_dependencies: ["bandit[toml]"]
```

### With Severity Filtering

Run the hook but only fail on HIGH severity issues:

```yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: '1.8.3'
    hooks:
      - id: bandit
        args: ["--severity-level", "high"]
```

### With Baseline

Apply a baseline to ignore pre-existing issues:

```yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: '1.8.3'
    hooks:
      - id: bandit
        args: ["-b", ".bandit-baseline.json"]
        additional_dependencies: ["bandit[baseline]"]
```

### Excluding Directories

Exclude test directories from the pre-commit scan (tests legitimately use `assert` and other flagged patterns):

```yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: '1.8.3'
    hooks:
      - id: bandit
        args: ["--exclude", "tests,migrations"]
```

---

## GitHub Actions

### Minimal Workflow (using bandit-action)

The official `PyCQA/bandit-action` publishes results as SARIF to GitHub Code Scanning, enabling inline annotations on pull requests.

```yaml
name: Bandit Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write   # required for uploading SARIF
      actions: read            # required for private repositories
      contents: read
    steps:
      - name: Perform Bandit Analysis
        uses: PyCQA/bandit-action@v1
```

### With Configuration Inputs

```yaml
jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read
    steps:
      - name: Perform Bandit Analysis
        uses: PyCQA/bandit-action@v1
        with:
          configfile: pyproject.toml
          severity: medium       # report medium and above
          confidence: medium     # report medium and above
          exclude: tests,migrations,venv
          targets: src/
```

Available inputs for `bandit-action`:

| Input | Description | Default |
|---|---|---|
| `configfile` | Config file path | DEFAULT |
| `profile` | Named test profile | DEFAULT |
| `tests` | Comma-separated test IDs to run | DEFAULT |
| `skips` | Comma-separated test IDs to skip | DEFAULT |
| `severity` | Minimum severity: `all`, `low`, `medium`, `high` | DEFAULT |
| `confidence` | Minimum confidence: `all`, `low`, `medium`, `high` | DEFAULT |
| `exclude` | Comma-separated paths/globs to exclude | `.svn,CVS,.bzr,.hg,.git,...` |
| `baseline` | Path to JSON baseline file | DEFAULT |
| `ini` | Path to `.bandit` INI file | DEFAULT |
| `targets` | Source files or directories to scan | `.` |

### Manual pip-based Workflow

For more control without `bandit-action`:

```yaml
name: Bandit

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install Bandit
        run: pip install "bandit[toml,sarif]"

      - name: Run Bandit
        run: |
          bandit -c pyproject.toml -r src/ \
            --severity-level medium \
            --confidence-level medium \
            -f sarif -o bandit-results.sarif

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        if: always()    # upload even if bandit exits non-zero
        with:
          sarif_file: bandit-results.sarif
```

### Blocking on Findings

Bandit exits non-zero when issues are found, which will fail the workflow step by default. Control this behavior:

```yaml
- name: Run Bandit (non-blocking)
  run: bandit -r . -lll || true    # always pass — use for reporting only

- name: Run Bandit (block on HIGH only)
  run: bandit -r . --severity-level high --confidence-level medium
```

### Caching pip Dependencies

```yaml
- name: Cache pip
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-bandit-${{ hashFiles('**/requirements*.txt') }}

- name: Install Bandit
  run: pip install bandit
```

---

## Baseline Strategy

Baselines allow teams to adopt Bandit incrementally by ignoring pre-existing issues and only blocking newly introduced ones.

### Creating a Baseline

```bash
# Scan current codebase and save all findings as the baseline
bandit -r . -f json -o .bandit-baseline.json

# Commit the baseline
git add .bandit-baseline.json
git commit -m "chore(security): add bandit baseline"
```

### Using the Baseline

All future scans compare against the baseline — only new findings cause failures:

```bash
bandit -r . -b .bandit-baseline.json
```

In pre-commit:

```yaml
- id: bandit
  args: ["-b", ".bandit-baseline.json"]
  additional_dependencies: ["bandit[baseline]"]
```

In GitHub Actions:

```yaml
- name: Run Bandit with baseline
  run: bandit -r . -b .bandit-baseline.json -f sarif -o results.sarif
```

### Maintaining the Baseline

Periodically review and reduce the baseline by resolving findings:

```bash
# Check what is in the current baseline
cat .bandit-baseline.json | python -m json.tool | grep '"test_id"'

# After fixing findings, regenerate the baseline
bandit -r . -f json -o .bandit-baseline.json
git add .bandit-baseline.json
git commit -m "fix(security): resolve B506 yaml.load findings"
```

Never let the baseline grow — each new entry represents an unresolved vulnerability accepted as technical debt.

---

## Adopting Bandit on Legacy Codebases

### Phase 1: Assess (non-blocking)

Run Bandit without failing the build to understand the scope:

```bash
bandit -r . -f json -o full-report.json || true
# Count findings by severity
python -c "
import json
r = json.load(open('full-report.json'))
from collections import Counter
print(Counter(i['issue_severity'] for i in r['results']))
"
```

### Phase 2: Baseline Existing Issues

```bash
bandit -r . -f json -o .bandit-baseline.json
git add .bandit-baseline.json && git commit -m "chore: add bandit baseline"
```

### Phase 3: Enforce New Issues in CI

Add Bandit to CI with the baseline — all new code must be clean:

```yaml
- name: Bandit (block new issues)
  run: bandit -r . -b .bandit-baseline.json
```

### Phase 4: Incrementally Reduce Baseline

Schedule regular sprints to resolve findings and remove them from the baseline, eventually targeting zero:

```bash
# See all outstanding findings
bandit -r . -f json | python -c "
import json, sys
data = json.load(sys.stdin)
for issue in sorted(data['results'], key=lambda x: x['issue_severity'], reverse=True):
    print(f\"{issue['issue_severity']:6} {issue['test_id']} {issue['filename']}:{issue['line_number']}\")
"
```

---

## Enforcing Severity Thresholds

### Team Policy Recommendations

| Severity + Confidence | Recommended Policy |
|---|---|
| HIGH + HIGH | Always block — fix immediately |
| HIGH + MEDIUM | Block in CI — fix before merge |
| MEDIUM + HIGH | Block in CI — fix or justify with `# nosec` |
| MEDIUM + MEDIUM | Warn, review in PR — team decision |
| LOW + any | Optional — skip noisy tests via config |

### pyproject.toml Tiered Configuration

```toml
[tool.bandit]
exclude_dirs = ["tests", "migrations", "scripts"]
skips = [
  "B101",   # assert_used — idiomatic in tests
  "B311",   # random — non-cryptographic use acceptable in this project
]
```

---

## Multi-format Reporting

Generate reports in multiple formats simultaneously for different audiences:

```bash
#!/bin/bash
# scan.sh — generate reports in screen, JSON, and HTML formats
bandit -r src/ \
  --severity-level low \
  --confidence-level low \
  -f screen   # terminal summary

bandit -r src/ -f json -o reports/bandit.json
bandit -r src/ -f html -o reports/bandit.html
```

### Parsing JSON Results Programmatically

```python
import json
from pathlib import Path

report = json.loads(Path("reports/bandit.json").read_text())

metrics = report["metrics"]
results = report["results"]

print(f"Files scanned: {metrics['_totals']['loc']} lines")
print(f"Issues found:  {len(results)}")
for issue in results:
    print(
        f"  [{issue['issue_severity']:6}] {issue['test_id']} "
        f"{issue['filename']}:{issue['line_number']} — {issue['issue_text']}"
    )
```

### SARIF for GitHub Advanced Security

SARIF output integrates with GitHub's Security tab and shows inline annotations on PRs:

```bash
pip install "bandit[sarif]"
bandit -r . -f sarif -o bandit.sarif
# Then upload via github/codeql-action/upload-sarif@v3
```
