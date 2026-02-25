# Bandit Plugin Reference

Complete listing of all Bandit test plugins organized by category, with severity, confidence, description, and recommended fix patterns.

## Table of Contents

- [B1xx — Miscellaneous](#b1xx--miscellaneous)
- [B2xx — App/Framework Misconfiguration](#b2xx--appframework-misconfiguration)
- [B3xx — Blacklisted Calls](#b3xx--blacklisted-calls)
- [B4xx — Blacklisted Imports](#b4xx--blacklisted-imports)
- [B5xx — Cryptography](#b5xx--cryptography)
- [B6xx — Injection](#b6xx--injection)
- [B7xx — XSS](#b7xx--xss)

---

## B1xx — Miscellaneous

| ID | Name | Severity | Confidence |
|---|---|---|---|
| B101 | assert_used | LOW | HIGH |
| B102 | exec_used | MEDIUM | HIGH |
| B103 | set_bad_file_permissions | MEDIUM | MEDIUM |
| B104 | hardcoded_bind_all_interfaces | MEDIUM | MEDIUM |
| B105 | hardcoded_password_string | LOW | MEDIUM |
| B106 | hardcoded_password_funcarg | LOW | MEDIUM |
| B107 | hardcoded_password_default | LOW | MEDIUM |
| B108 | hardcoded_tmp_directory | MEDIUM | MEDIUM |
| B109 | password_config_option_not_marked_secret | LOW | MEDIUM |
| B110 | try_except_pass | LOW | HIGH |
| B111 | execute_with_run_as_root_equals_true | LOW | MEDIUM |
| B112 | try_except_continue | LOW | HIGH |
| B113 | request_without_timeout | MEDIUM | LOW |

### B101 — assert_used

Python strips `assert` statements when running with the `-O` flag. Never rely on `assert` for authorization or validation in production code.

```python
# Bad
assert user.is_authenticated

# Good
if not user.is_authenticated:
    raise PermissionError("Authentication required")
```

Skip this test in test suites: `skips = ["B101"]` — asserts are idiomatic in `pytest`.

### B102 — exec_used

`exec()` allows arbitrary code execution. Avoid entirely; if dynamic evaluation is needed, use `ast.literal_eval()` for safe literal parsing.

```python
# Bad
exec(user_data)

# Good — for config values only
import ast
value = ast.literal_eval(user_input)
```

### B103 — set_bad_file_permissions

Detects overly permissive `os.chmod` calls (e.g., `0o777`, `0o666`).

```python
# Bad
os.chmod("/etc/app/config", 0o777)

# Good — minimal permissions
os.chmod("/etc/app/config", 0o600)  # owner read/write only
```

### B104 — hardcoded_bind_all_interfaces

Binding to `0.0.0.0` exposes the service on all network interfaces, including public ones.

```python
# Bad
server.bind(("0.0.0.0", 8080))

# Good — bind to localhost or a specific interface in non-prod
server.bind(("127.0.0.1", 8080))
# Use 0.0.0.0 only when intentionally exposing publicly, and suppress:
# server.bind(("0.0.0.0", 8080))  # nosec B104 — intentional public binding
```

### B105 / B106 / B107 — Hardcoded passwords

Detects password/secret literals in assignments, function arguments, and default parameter values.

```python
# Bad — B105
password = "secret123"

# Bad — B106
connect(password="hunter2")

# Bad — B107
def connect(password="default_pass"):
    ...

# Good — read from environment or secrets manager
import os
password = os.environ["DB_PASSWORD"]
```

### B108 — hardcoded_tmp_directory

Hardcoded `/tmp` paths are predictable and vulnerable to symlink attacks.

```python
# Bad
open("/tmp/myapp.lock", "w")

# Good — use tempfile module
import tempfile
with tempfile.NamedTemporaryFile() as f:
    f.write(data)
```

### B110 — try_except_pass

Silent exception swallowing hides errors and can mask security events.

```python
# Bad
try:
    authenticate(user)
except Exception:
    pass

# Good — at minimum, log the exception
try:
    authenticate(user)
except AuthError as e:
    logger.warning("Auth failed: %s", e)
    raise
```

### B113 — request_without_timeout

HTTP requests without a timeout can hang indefinitely, enabling denial-of-service conditions.

```python
# Bad
requests.get(url)

# Good
requests.get(url, timeout=10)
```

---

## B2xx — App/Framework Misconfiguration

| ID | Name | Severity | Confidence |
|---|---|---|---|
| B201 | flask_debug_true | HIGH | MEDIUM |
| B202 | tarfile_unsafe_members | HIGH | HIGH |

### B201 — flask_debug_true

Flask debug mode enables an interactive debugger accessible over HTTP — a critical vulnerability in production.

```python
# Bad
app.run(debug=True)

# Good — control via environment variable
import os
app.run(debug=os.environ.get("FLASK_DEBUG", "false").lower() == "true")
```

### B202 — tarfile_unsafe_members

`tarfile.extractall()` without filtering allows path traversal attacks (zip-slip). Members can write files outside the extraction directory.

```python
# Bad
tar.extractall(path=destination)

# Good — filter members before extracting
import os
def safe_members(members, dest):
    dest = os.path.realpath(dest)
    for member in members:
        member_path = os.path.realpath(os.path.join(dest, member.name))
        if member_path.startswith(dest):
            yield member

tar.extractall(path=destination, members=safe_members(tar, destination))
```

---

## B3xx — Blacklisted Calls

Blacklisted calls cover dangerous standard library functions. The ID scheme B3xx applies to function calls.

| ID | Name | Common Trigger | Severity |
|---|---|---|---|
| B301 | pickle | `pickle.loads`, `pickle.load` | MEDIUM |
| B302 | marshal | `marshal.loads` | MEDIUM |
| B303 | md5 | `hashlib.md5`, `Crypto.Hash.MD5` | MEDIUM |
| B304 | ciphers | DES, RC2, RC4, ARC2, ARC4 | HIGH |
| B305 | cipher_modes | ECB mode usage | MEDIUM |
| B306 | mktemp_q | `tempfile.mktemp` | MEDIUM |
| B307 | eval | `eval()` | MEDIUM |
| B310 | urllib_urlopen | `urllib.request.urlopen` | MEDIUM |
| B311 | random | `random.random`, `random.randint` | LOW |
| B312 | telnetlib | Any telnetlib usage | HIGH |
| B313–B320 | xml_* | `xml.etree`, `xml.sax`, `xml.dom`, `minidom` | MEDIUM |
| B321 | ftp | ftplib usage | HIGH |
| B322 | input | `input()` in Python 2 | HIGH |
| B323 | unverified_context | `ssl._create_unverified_context` | MEDIUM |
| B324 | hashlib | `hashlib.md5`, `hashlib.sha1` (non-`usedforsecurity`) | MEDIUM |
| B325 | tempnam | `os.tempnam`, `os.tmpnam` | MEDIUM |

### B301 — pickle

`pickle.loads()` executes arbitrary Python code embedded in the data. Never deserialize untrusted pickle data.

```python
# Bad
import pickle
data = pickle.loads(user_bytes)

# Good — use safe formats for external data
import json
data = json.loads(user_bytes)

# If pickle is required for internal trusted data only:
# pickle.loads(trusted_bytes)  # nosec B301 — internal IPC only, not user input
```

### B307 — eval

`eval()` executes arbitrary Python expressions. Treat it the same as `exec`.

```python
# Bad
result = eval(expression)

# Good
import ast
result = ast.literal_eval(expression)   # safe for literals only
```

### B311 — random (non-cryptographic)

`random` is not cryptographically secure. Never use it for tokens, passwords, or security-sensitive values.

```python
# Bad
token = str(random.random())

# Good
import secrets
token = secrets.token_hex(32)
```

### B324 — hashlib weak hash

`hashlib.md5()` and `hashlib.sha1()` are considered weak for security contexts. Python 3.9+ accepts `usedforsecurity=False` to suppress the warning for non-security uses.

```python
# Bad — security context
digest = hashlib.md5(password.encode()).hexdigest()

# Good — security context
digest = hashlib.sha256(password.encode()).hexdigest()

# Acceptable — non-security use (cache keys, checksums)
checksum = hashlib.md5(data, usedforsecurity=False).hexdigest()
```

---

## B4xx — Blacklisted Imports

| ID | Name | Trigger | Severity |
|---|---|---|---|
| B401 | import_telnetlib | `import telnetlib` | HIGH |
| B402 | import_ftplib | `import ftplib` | HIGH |
| B403 | import_pickle | `import pickle` | LOW |
| B404 | import_subprocess | `import subprocess` | LOW |
| B405 | import_xml_etree | `import xml.etree.cElementTree` | LOW |
| B406 | import_xml_sax | `import xml.sax` | LOW |
| B407 | import_xml_expat | `import xml.dom.expatbuilder` | LOW |
| B408 | import_xml_minidom | `import xml.dom.minidom` | LOW |
| B409 | import_xml_pulldom | `import xml.dom.pulldom` | LOW |
| B410 | import_lxml | `import lxml` | LOW |
| B411 | import_xmlrpclib | `import xmlrpclib` | HIGH |
| B412 | import_httpoxy | `import httpoxy` | HIGH |
| B413 | import_pycrypto | `import Crypto` | HIGH |
| B415 | import_pyghmi | `import pyghmi` | HIGH |

Import blacklists flag modules known to be insecure or deprecated. Many have safe alternatives:

| Risky Import | Safe Alternative |
|---|---|
| `import pickle` | `import json`, `import msgpack` |
| `import telnetlib` | `import paramiko` (SSH) |
| `import ftplib` | `import paramiko` (SFTP) |
| `xml.*` (stdlib) | `import defusedxml` |
| `import Crypto` (pycrypto) | `import cryptography` (pyca) |

---

## B5xx — Cryptography

| ID | Name | Severity | Confidence |
|---|---|---|---|
| B501 | request_with_no_cert_validation | HIGH | HIGH |
| B502 | ssl_with_bad_version | HIGH | MEDIUM |
| B503 | ssl_with_bad_defaults | MEDIUM | MEDIUM |
| B504 | ssl_with_no_version | LOW | MEDIUM |
| B505 | weak_cryptographic_key | HIGH | HIGH |
| B506 | yaml_load | MEDIUM | HIGH |
| B507 | ssh_no_host_key_verification | HIGH | MEDIUM |
| B508 | snmp_insecure_version | HIGH | HIGH |
| B509 | snmp_weak_cryptography | MEDIUM | MEDIUM |

### B501 — No certificate validation

```python
# Bad
requests.get(url, verify=False)
ssl._create_unverified_context()

# Good
requests.get(url)                      # verify defaults to True
ssl.create_default_context()           # validates by default
```

### B502 — Bad SSL version

Explicit use of `SSLv2`, `SSLv3`, `TLSv1`, or `TLSv1.1` is prohibited. These versions have known vulnerabilities.

```python
# Bad
ssl.wrap_socket(sock, ssl_version=ssl.PROTOCOL_TLSv1)

# Good
ssl.wrap_socket(sock, ssl_version=ssl.PROTOCOL_TLS_CLIENT)
# Or use ssl.SSLContext with minimum version:
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
```

### B505 — Weak cryptographic key

Key sizes below recommended minimums are flagged:

| Algorithm | Minimum Safe Size |
|---|---|
| RSA | 2048 bits |
| DSA | 2048 bits |
| EC | 224 bits |

```python
# Bad
from cryptography.hazmat.primitives.asymmetric import rsa
key = rsa.generate_private_key(public_exponent=65537, key_size=1024)

# Good
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
```

### B506 — yaml.load()

`yaml.load()` without a Loader executes arbitrary Python via the `!!python/object` tag.

```python
# Bad
yaml.load(stream)

# Good
yaml.safe_load(stream)
yaml.load(stream, Loader=yaml.SafeLoader)
```

### B507 — SSH no host key verification

Disabling host key verification makes SSH connections vulnerable to MITM attacks.

```python
# Bad
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# Good — verify against known_hosts
client.load_system_host_keys()
client.set_missing_host_key_policy(paramiko.RejectPolicy())
```

---

## B6xx — Injection

| ID | Name | Severity | Confidence |
|---|---|---|---|
| B601 | paramiko_calls | MEDIUM | MEDIUM |
| B602 | subprocess_popen_with_shell_equals_true | HIGH | HIGH |
| B603 | subprocess_without_shell_equals_true | LOW | HIGH |
| B604 | any_other_function_with_shell_equals_true | MEDIUM | LOW |
| B605 | start_process_with_a_shell | HIGH | HIGH |
| B606 | start_process_with_no_shell | LOW | MEDIUM |
| B607 | start_process_with_partial_path | LOW | HIGH |
| B608 | hardcoded_sql_expressions | MEDIUM | MEDIUM |
| B609 | linux_commands_wildcard_injection | HIGH | MEDIUM |
| B610 | django_extra_used | MEDIUM | MEDIUM |
| B611 | django_rawsql_used | MEDIUM | MEDIUM |
| B612 | logging_config_insecure_listen | HIGH | HIGH |
| B613 | trojansource | HIGH | HIGH |
| B614 | pytorch_load | MEDIUM | MEDIUM |
| B615 | huggingface_unsafe_download | MEDIUM | MEDIUM |

### B602 — subprocess with shell=True

The most commonly flagged injection vector. Passing user input with `shell=True` allows arbitrary command execution.

```python
# Bad — command injection if `name` contains shell metacharacters
subprocess.Popen(f"echo {name}", shell=True)

# Good — list form, no shell expansion
subprocess.Popen(["echo", name])
```

### B608 — Hardcoded SQL expressions

String-formatted SQL queries are vulnerable to SQL injection.

```python
# Bad
query = "SELECT * FROM users WHERE email = '" + email + "'"
cursor.execute(query)

# Good — parameterized queries
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))

# Good — ORM (Django, SQLAlchemy)
User.objects.filter(email=email)
```

### B609 — Wildcard injection in Linux commands

Wildcards in shell commands can be exploited when filenames contain special characters.

```python
# Bad — attacker can create a file named `--checkpoint-action=exec=evil.sh`
os.system("tar cf backup.tar *")

# Good — enumerate files explicitly
import glob
files = glob.glob("*.py")
subprocess.run(["tar", "cf", "backup.tar"] + files)
```

### B613 — TrojanSource

Detects bidirectional Unicode control characters in source code that can visually disguise malicious code.

Fix: use an editor/linter that flags non-ASCII control characters, and enforce ASCII-only identifiers in sensitive code.

---

## B7xx — XSS

| ID | Name | Severity | Confidence |
|---|---|---|---|
| B701 | jinja2_autoescape_false | HIGH | HIGH |
| B702 | use_of_mako_templates | MEDIUM | HIGH |
| B703 | django_mark_safe | MEDIUM | MEDIUM |
| B704 | markupsafe_markup_xss | HIGH | HIGH |

### B701 — Jinja2 autoescape disabled

Disabling autoescape in Jinja2 allows XSS when user-controlled data is rendered.

```python
# Bad
env = jinja2.Environment(autoescape=False)

# Good
env = jinja2.Environment(autoescape=True)
# or use select_autoescape for fine-grained control:
from jinja2 import select_autoescape
env = jinja2.Environment(autoescape=select_autoescape(['html', 'xml']))
```

### B703 — django mark_safe

`mark_safe()` bypasses Django's auto-escaping. Only use on strings that have been explicitly sanitized.

```python
# Bad — user input passed to mark_safe
from django.utils.safestring import mark_safe
output = mark_safe(user_comment)

# Good — use Django's template engine to escape, or sanitize first
from django.utils.html import escape
output = escape(user_comment)
```

### B704 — MarkupSafe Markup XSS

`Markup()` from MarkupSafe marks a string as safe HTML. Do not wrap user input directly.

```python
# Bad
from markupsafe import Markup
html = Markup(user_input)

# Good — escape user input before wrapping
from markupsafe import Markup, escape
html = Markup(escape(user_input))
```
