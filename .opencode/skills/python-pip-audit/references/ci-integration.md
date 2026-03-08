# pip-audit CI/CD Integration

## GitHub Actions

### Basic workflow (recommended starting point)

Use the official `pypa/gh-action-pip-audit` action:

```yaml
# .github/workflows/pip-audit.yml
name: Dependency Audit

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 6 * * 1'   # Weekly on Monday at 06:00 UTC

jobs:
  pip-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pypa/gh-action-pip-audit@v1.0.0
        with:
          inputs: requirements.txt
```

### With OSV vulnerability service

```yaml
      - uses: pypa/gh-action-pip-audit@v1.0.0
        with:
          inputs: requirements.txt
          vulnerability-service: osv
```

### Audit the installed environment (after pip install)

```yaml
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -r requirements.txt
      - uses: pypa/gh-action-pip-audit@v1.0.0
```

### Save JSON report as artifact

```yaml
      - name: Run pip-audit
        run: |
          pip install pip-audit
          pip-audit -r requirements.txt -f json -o audit-report.json || true
      - uses: actions/upload-artifact@v4
        with:
          name: pip-audit-report
          path: audit-report.json
```

### Fail only on fixable vulnerabilities

```yaml
      - name: Audit (fail only on fixable)
        run: |
          pip install pip-audit jq
          test -z "$(pip-audit -r requirements.txt --format=json 2>/dev/null \
            | jq '.dependencies[].vulns[].fix_versions[]')"
```

### Ignore specific advisories in CI

```yaml
      - uses: pypa/gh-action-pip-audit@v1.0.0
        with:
          inputs: requirements.txt
          ignore-vulns: |
            GHSA-w596-4wvx-j9j6
            CVE-2019-1010083
```

---

## pre-commit Hook

Run pip-audit as a pre-commit hook to catch vulnerabilities before commits reach CI.

### Minimal configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pypa/pip-audit
    rev: v2.10.0
    hooks:
      - id: pip-audit
        args: ["-r", "requirements.txt"]
```

### With hash checking (supply-chain integrity)

```yaml
      - id: pip-audit
        args: ["-r", "requirements.txt", "--require-hashes"]
```

### Skip in pre-commit.ci (network calls not allowed)

```yaml
ci:
  skip: [pip-audit]
```

pre-commit.ci does not permit outbound network access. Exclude pip-audit from remote CI runs and rely on the GitHub Actions workflow instead.

### Install and run pre-commit locally

```bash
pip install pre-commit
pre-commit install
pre-commit run pip-audit --all-files
```

---

## Makefile Targets

Standard targets for local development and CI parity:

```makefile
.PHONY: audit audit-fix audit-json

audit:
	pip-audit -r requirements.txt --desc

audit-fix:
	pip-audit -r requirements.txt --fix

audit-json:
	pip-audit -r requirements.txt -f json -o audit-report.json

audit-osv:
	pip-audit -r requirements.txt -s osv --desc --aliases
```

---

## Baseline Workflow for Existing Codebases

Adopt pip-audit incrementally by establishing a baseline that blocks only new vulnerabilities:

```bash
# 1. Generate baseline from current state (accept existing known issues)
pip-audit -r requirements.txt -f json -o .pip-audit-baseline.json || true

# 2. Commit baseline
git add .pip-audit-baseline.json

# 3. Future runs compare against baseline — only new issues fail
pip-audit -r requirements.txt -b .pip-audit-baseline.json
```

Baseline support requires `pip install "pip-audit[baseline]"`.

Regenerate the baseline after intentionally accepting a new vulnerability:

```bash
pip-audit -r requirements.txt -f json -o .pip-audit-baseline.json || true
git add .pip-audit-baseline.json
git commit -m "chore(security): update pip-audit baseline"
```

---

## SBOM Generation

Generate a Software Bill of Materials alongside auditing for compliance:

```bash
# CycloneDX JSON
pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json

# CycloneDX XML
pip-audit -r requirements.txt -f cyclonedx-xml -o sbom.xml
```

Attach SBOMs as release artifacts in GitHub Actions:

```yaml
      - name: Generate SBOM
        run: |
          pip install pip-audit
          pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json
      - uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.json
```

---

## Multi-requirements Projects

Audit multiple requirements files in one pass:

```bash
pip-audit \
  -r requirements.txt \
  -r requirements-dev.txt \
  -r requirements-test.txt
```

Or loop in CI:

```bash
for req in requirements*.txt; do
  echo "=== Auditing $req ==="
  pip-audit -r "$req"
done
```

---

## Recommended CI Strategy

| Scenario | Approach |
|---|---|
| Greenfield project | `pip-audit -r requirements.txt --require-hashes` |
| Legacy codebase onboarding | Baseline workflow; block only new issues |
| Release pipeline | `pip-audit --require-hashes` + SBOM generation |
| Pull request checks | GitHub Action on `pull_request` event |
| Scheduled monitoring | Weekly cron job with JSON artifact |
| Development velocity | pre-commit hook + `--no-deps` for speed |
