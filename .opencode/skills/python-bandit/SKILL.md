---
name: python-bandit
description: This skill should be used when the user asks to "scan Python code for security issues", "set up Bandit", "configure bandit security linting", "fix bandit warnings", or needs guidance on Python static security analysis with Bandit.
---

# Python Bandit Security Scanning

Bandit is a static analysis tool that finds common security issues in Python code. It processes each file, builds an AST, and runs security-focused plugins against AST nodes. Results are categorized by severity (LOW, MEDIUM, HIGH) and confidence (LOW, MEDIUM, HIGH).

## Installation

Install the base package or add extras for specific features:

```bash
# Base installation
pip install bandit

# With TOML config support (pyproject.toml)
pip install "bandit[toml]"

# With SARIF output (for GitHub Advanced Security)
pip install "bandit[sarif]"

# With baseline support
pip install "bandit[baseline]"
```

Use the same Python version as the project under scan. Bandit relies on Python's `ast` module, which can only parse code valid for that interpreter version.

## Core Usage

**Scan a full project tree:**

```bash
bandit -r path/to/project/
```

**Scan with severity filter (report only HIGH):**

```bash
bandit -r . --severity-level high
# or shorthand: -lll (high), -ll (medium+), -l (low+)
bandit -r . -lll
```

**Scan with confidence filter:**

```bash
bandit -r . --confidence-level high
# shorthand: -iii (high), -ii (medium+), -i (low+)
```

**Target specific test IDs only:**

```bash
bandit -r . -t B105,B106,B107   # hardcoded password checks only
```

**Skip specific test IDs:**

```bash
bandit -r . -s B101             # skip assert_used (common in tests)
```

**Use a named profile:**

```bash
bandit examples/*.py -p ShellInjection
```

**Scan from stdin:**

```bash
cat myfile.py | bandit -
```

**Show N lines of context per finding:**

```bash
bandit -r . -n 3
```

## Configuration

### pyproject.toml (Recommended)

Centralize Bandit settings alongside other tooling:

```toml
[tool.bandit]
exclude_dirs = ["tests", "migrations", "venv"]
skips = ["B101"]          # assert_used — acceptable in test suites
tests = []                # empty = run all (minus skips)
```

Run with explicit config pointer:

```bash
bandit -c pyproject.toml -r .
```

### .bandit (INI — auto-discovered with -r)

```ini
[bandit]
exclude = tests,migrations
skips = B101,B601
tests = B201,B301
```

Bandit auto-discovers `.bandit` when invoked with `-r`. No `-c` flag needed.

### YAML Config

```yaml
exclude_dirs: ['tests', 'path/to/file']
tests: ['B201', 'B301']
skips: ['B101', 'B601']

# Override plugin-specific defaults
try_except_pass:
  check_typed_exception: true
```

Run: `bandit -c bandit.yaml -r .`

### Generate a Config Template

```bash
bandit-config-generator > bandit.yaml
# Then edit — remove sections you don't need, adjust defaults
```

## Suppressing False Positives

Mark individual lines with `# nosec` to suppress all findings:

```python
self.process = subprocess.Popen('/bin/echo', shell=True)  # nosec
```

Suppress specific test IDs only (preferred — avoids hiding future issues):

```python
self.process = subprocess.Popen('/bin/ls *', shell=True)  # nosec B602, B607
```

Use the full test name as an alternative to the ID:

```python
assert yaml.load("{}") == []  # nosec assert_used
```

**Always add a comment explaining why the suppression is justified.**

## Output Formats

```bash
bandit -r . -f json -o report.json      # JSON (required for baseline)
bandit -r . -f sarif -o report.sarif    # SARIF (GitHub Advanced Security)
bandit -r . -f csv -o report.csv        # CSV
bandit -r . -f xml -o report.xml        # XML
bandit -r . -f html -o report.html      # HTML
bandit -r . -f screen                   # Terminal (default)
bandit -r . -f yaml -o report.yaml      # YAML
```

## Baseline Workflow

Use baselines to track only new issues, ignoring pre-existing findings:

```bash
# 1. Generate a baseline from the current state of the codebase
bandit -r . -f json -o .bandit-baseline.json

# 2. Commit the baseline to version control
git add .bandit-baseline.json

# 3. Future scans compare against the baseline
bandit -r . -b .bandit-baseline.json
```

Useful when adopting Bandit on an existing codebase — block only newly introduced issues.

## Critical Plugin Categories

Bandit test IDs follow a group scheme:

| Range | Category |
|---|---|
| B1xx | Miscellaneous |
| B2xx | App/framework misconfiguration |
| B3xx | Blacklisted calls |
| B4xx | Blacklisted imports |
| B5xx | Cryptography |
| B6xx | Injection |
| B7xx | XSS |

### High-Priority Checks to Always Enforce

**Hardcoded secrets (B105, B106, B107)** — passwords assigned to variables, passed as function arguments, or set as default parameters.

**Injection (B602, B608)** — shell injection via `subprocess` with `shell=True`, SQL injection via hardcoded SQL string construction.

**Weak cryptography (B324, B501–B505)** — MD5/SHA1 use, disabled TLS certificate validation, weak SSL versions, short cryptographic keys.

**Unsafe deserialization (B301, B302, B303, B304)** — `pickle`, `marshal`, `yaml.load()` without `Loader`.

**Template injection (B701, B703, B704)** — Jinja2 autoescape disabled, Django `mark_safe`, MarkupSafe XSS.

### Common Findings and Fixes

**B101 — assert_used**

Asserts are stripped in optimized mode (`python -O`). Never use `assert` for security-critical checks.

```python
# Bad
assert user.is_admin, "Not authorized"

# Good
if not user.is_admin:
    raise PermissionError("Not authorized")
```

**B105/B106/B107 — Hardcoded password**

```python
# Bad
password = "hunter2"
connect(password="secret")

# Good — read from environment or secrets manager
import os
password = os.environ["DB_PASSWORD"]
```

**B324 — Weak hash (MD5/SHA1)**

```python
# Bad
import hashlib
hashlib.md5(data)

# Good — use SHA-256 or higher for security contexts
hashlib.sha256(data)
# If MD5 is for non-security use (checksums), suppress with comment:
hashlib.md5(data).hexdigest()  # nosec B324 — used for cache key, not security
```

**B506 — yaml.load()**

```python
# Bad — arbitrary code execution risk
import yaml
yaml.load(data)

# Good
yaml.safe_load(data)
# or
yaml.load(data, Loader=yaml.SafeLoader)
```

**B602 — subprocess with shell=True**

```python
# Bad — shell injection vector
subprocess.Popen(user_input, shell=True)

# Good — pass args as a list, avoid shell
subprocess.Popen(["ls", "-l", path])
```

**B608 — Hardcoded SQL**

```python
# Bad
query = "SELECT * FROM users WHERE name = '" + name + "'"

# Good — use parameterized queries
cursor.execute("SELECT * FROM users WHERE name = ?", (name,))
```

**B501 — No certificate validation**

```python
# Bad
requests.get(url, verify=False)

# Good
requests.get(url)                        # verify=True by default
requests.get(url, verify="/path/to/ca-bundle.crt")
```

## Severity Triage Workflow

1. Run Bandit with JSON output format and save results to a file (see Output Formats section above).
2. Fix all HIGH severity + HIGH confidence findings first — these are near-certain vulnerabilities.
3. Evaluate MEDIUM severity findings for false positives; suppress with documented `# nosec` if safe.
4. Decide team policy on LOW severity — consider skipping known false-positive-heavy tests via `skips`.
5. Establish a baseline for legacy codebases to avoid alert fatigue during adoption.

## Additional Resources

- **`references/plugin-reference.md`** — Complete B-code listing with severity, description, and fix pattern per plugin
- **`references/ci-cd-integration.md`** — Pre-commit hooks, GitHub Actions, and baseline automation workflows
