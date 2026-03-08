---
name: python-pip-audit
description: This skill should be used when the user asks to "audit Python dependencies for vulnerabilities", "scan requirements.txt for CVEs", "set up pip-audit", "fix vulnerable Python packages", or needs guidance on Python dependency security scanning with pip-audit.
---

# Python pip-audit Dependency Security Scanning

pip-audit scans Python environments and requirements files for packages with known vulnerabilities. It queries the Python Packaging Advisory Database via the PyPI JSON API and the OSV database, reporting CVEs, GHSA IDs, and fix versions.

## Installation

Install pip-audit into the project's virtual environment or as a standalone tool:

```bash
# Into active virtual environment
pip install pip-audit

# Isolated global install (preferred for CI)
pipx install pip-audit

# Via conda
conda install -c conda-forge pip-audit
```

pip-audit requires Python 3.10 or newer.

## Core Usage

**Audit the current environment:**

```bash
pip-audit
```

**Audit a requirements file:**

```bash
pip-audit -r requirements.txt
```

**Audit a local Python project (reads `pyproject.toml` or `pylock.*.toml`):**

```bash
pip-audit .
```

**Audit lock files only:**

```bash
pip-audit --locked .
```

**Exclude system packages (useful inside virtual environments):**

```bash
pip-audit -r requirements.txt -l
```

## Vulnerability Services

pip-audit supports two vulnerability data sources:

| Service | Flag | Default |
|---|---|---|
| PyPI JSON API | `-s pypi` | Yes |
| OSV (Open Source Vulnerabilities) | `-s osv` | No |

Use OSV for broader advisory coverage across multiple ecosystems:

```bash
pip-audit -r requirements.txt -s osv
```

Switch the OSV API endpoint (e.g., for self-hosted instances):

```bash
pip-audit -r requirements.txt -s osv --osv-url https://api.osv.dev/v1/query
```

## Output Formats

```bash
pip-audit -f columns          # Default columnar output
pip-audit -f json             # Machine-readable JSON
pip-audit -f markdown         # Markdown table
pip-audit -f cyclonedx-json   # CycloneDX SBOM (JSON)
pip-audit -f cyclonedx-xml    # CycloneDX SBOM (XML)
```

Save output to a file:

```bash
pip-audit -f json -o audit-report.json
```

Include vulnerability descriptions and alias IDs (CVE/GHSA) in output:

```bash
pip-audit --desc --aliases
```

For JSON format, descriptions and aliases are included automatically.

## Automatic Fix

Upgrade vulnerable packages automatically:

```bash
pip-audit --fix
```

Preview what would be upgraded without applying changes:

```bash
pip-audit --fix --dry-run
```

Dry run without the `--fix` flag reports how many dependencies *would* be audited:

```bash
pip-audit --dry-run
```

## Ignoring Specific Vulnerabilities

Suppress known false positives or accepted risks using the vulnerability ID, CVE, or GHSA alias:

```bash
# Ignore by PYSEC ID
pip-audit --ignore-vuln PYSEC-2021-666

# Ignore by CVE
pip-audit --ignore-vuln CVE-2019-1010083

# Ignore by GHSA
pip-audit --ignore-vuln GHSA-w596-4wvx-j9j6

# Ignore multiple
pip-audit --ignore-vuln CVE-XXX-YYYY --ignore-vuln GHSA-abc-def-ghij
```

Document every suppressed ID in a comment or issue tracker entry explaining why it is not applicable.

## Performance: Skipping Dependency Resolution

pip-audit performs its own dependency resolution by default, which can be slow. Skip resolution when inputs are already fully pinned:

**Pinned without hashes (faster):**

```bash
pip-audit --no-deps -r requirements.txt
```

**Pinned with hashes (fastest, most secure):**

```bash
pip-audit --require-hashes -r requirements.txt
```

`--require-hashes` is equivalent to pip's hash-checking mode. It fails if any package is missing a hash, providing additional supply-chain integrity.

**Audit a pre-installed environment directly (no resolution needed):**

```bash
pip-audit
pip-audit --local   # only local packages, skip globally installed
```

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | No known vulnerabilities found |
| `1` | One or more vulnerabilities found |

Exit codes cannot be suppressed internally. Use shell idioms when needed:

```bash
# Continue even if vulnerabilities found
pip-audit || true

# Capture for custom handling
pip-audit
exitcode="${?}"
```

## Environment Variables

Configure pip-audit without flags for CI pipelines:

| Variable | Equivalent flag | Example value |
|---|---|---|
| `PIP_AUDIT_FORMAT` | `--format` | json |
| `PIP_AUDIT_VULNERABILITY_SERVICE` | `--vulnerability-service` | osv |
| `PIP_AUDIT_DESC` | `--desc` | off |
| `PIP_AUDIT_PROGRESS_SPINNER` | `--progress-spinner` | off |
| `PIP_AUDIT_OUTPUT` | `--output` | audit-report.json |

## Reporting Only Fixable Vulnerabilities

Filter to only fail when vulnerabilities have known fix versions using `jq`:

```bash
test -z "$(pip-audit -r requirements.txt --format=json 2>/dev/null \
  | jq '.dependencies[].vulns[].fix_versions[]')"
```

This exits non-zero only when at least one fixable vulnerability exists.

## pipenv Projects

Convert `Pipfile.lock` to a requirements format and pipe directly:

```bash
pipenv run pip-audit -r <(pipenv requirements)
```

## Private Package Indices

Use `--index-url` and `--extra-index-url` to point at internal registries:

```bash
pip-audit -r requirements.txt \
  --index-url https://pypi.example.com/simple/ \
  --extra-index-url https://pypi.org/simple/
```

Interactive authentication is not supported. Use keyring via the subprocess provider or set credentials in the URL or environment.

## Security Model

pip-audit detects *known* vulnerabilities in *direct and transitive* Python dependencies. It does not:

- Perform static code analysis
- Detect vulnerabilities in native shared libraries linked by Python packages
- Protect against malicious packages not yet in any advisory database

Treat `pip-audit -r INPUT` as equivalent to `pip install -r INPUT` — it resolves and downloads packages. Only audit inputs from trusted sources.

## Additional Resources

- **`references/ci-integration.md`** — GitHub Actions workflow, pre-commit hook, and baseline automation patterns
