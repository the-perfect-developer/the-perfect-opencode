---
name: python-pymysql
description: This skill should be used when the user asks to "connect to MySQL with PyMySQL", "use PyMySQL in Python", "query a MySQL database with Python", "set up PyMySQL", or needs guidance on PyMySQL best practices, transactions, parameterized queries, or cursor types.
---

# PyMySQL Best Practices

PyMySQL is a pure-Python MySQL client library implementing the DB-API 2.0 specification (PEP 249). It supports MySQL >= 5.7 and MariaDB >= 10.3 on Python >= 3.7.

## Installation

```bash
pip install PyMySQL

# For SHA-256 / caching_sha2_password authentication:
pip install "PyMySQL[rsa]"
```

## Establishing a Connection

Use `pymysql.connect()` as the entry point. Always specify `charset='utf8mb4'` and use context managers to guarantee cleanup.

```python
import pymysql
import pymysql.cursors

connection = pymysql.connect(
    host="localhost",
    user="app_user",
    password="secret",
    database="mydb",
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
    connect_timeout=10,
    read_timeout=30,
    write_timeout=30,
    autocommit=False,  # explicit transaction control (recommended)
)
```

### Key Connection Parameters

| Parameter | Default | Notes |
|---|---|---|
| `charset` | `''` | Always set `utf8mb4` for full Unicode support |
| `cursorclass` | `Cursor` | Use `DictCursor` for dict rows; `SSCursor` for large result sets |
| `autocommit` | `False` | Keep `False`; commit/rollback explicitly |
| `connect_timeout` | `10` | Seconds before connection attempt fails |
| `read_timeout` | `None` | Set to prevent hung reads |
| `write_timeout` | `None` | Set to prevent hung writes |
| `ssl_ca` | `None` | Path to CA cert for TLS connections |

## Context Manager Usage

Connections and cursors implement the context manager protocol. Use `with` blocks to ensure proper resource cleanup.

```python
# Connection as context manager — commits on success, rolls back on exception
with pymysql.connect(**db_config) as connection:
    with connection.cursor() as cursor:
        cursor.execute("SELECT id, email FROM users WHERE active = %s", (1,))
        rows = cursor.fetchall()
```

> **Note**: Using `with connection:` handles transaction commit/rollback but does **not** close the connection. Call `connection.close()` explicitly or manage it via a pool.

## Parameterized Queries (SQL Injection Prevention)

Always pass values as the second argument to `execute()`. Never use string formatting or concatenation to build SQL.

```python
# Correct — parameterized
cursor.execute(
    "INSERT INTO orders (user_id, amount) VALUES (%s, %s)",
    (user_id, amount),
)

# Named placeholders with dict
cursor.execute(
    "SELECT * FROM products WHERE category = %(cat)s AND price < %(max_price)s",
    {"cat": "electronics", "max_price": 500},
)

# WRONG — never do this
cursor.execute(f"SELECT * FROM users WHERE name = '{name}'")  # SQL injection risk
```

Use `cursor.mogrify(query, args)` to preview the interpolated query string during debugging.

## Cursor Types

| Cursor Class | Returns | Buffered | Use Case |
|---|---|---|---|
| `Cursor` | tuple | Yes | Default; small-to-medium result sets |
| `DictCursor` | dict | Yes | When column-name access is needed |
| `SSCursor` | tuple | No | Large result sets; memory-constrained |
| `SSDictCursor` | dict | No | Large result sets with dict access |

Pass `cursorclass` at connection time (global default) or per-cursor:

```python
# Per-cursor override
with connection.cursor(pymysql.cursors.DictCursor) as cursor:
    cursor.execute("SELECT * FROM users")
    rows = cursor.fetchall()  # list of dicts
```

For large tables, prefer `SSCursor` and iterate without calling `fetchall()`:

```python
with connection.cursor(pymysql.cursors.SSCursor) as cursor:
    cursor.execute("SELECT * FROM large_table")
    for row in cursor:  # streams row-by-row
        process(row)
```

## Transaction Management

PyMySQL defaults to `autocommit=False`. Explicitly commit successful work and roll back on errors.

```python
try:
    with connection.cursor() as cursor:
        cursor.execute(
            "UPDATE accounts SET balance = balance - %s WHERE id = %s",
            (amount, from_id),
        )
        cursor.execute(
            "UPDATE accounts SET balance = balance + %s WHERE id = %s",
            (amount, to_id),
        )
    connection.commit()
except Exception:
    connection.rollback()
    raise
```

Call `connection.begin()` to start a transaction block explicitly when needed.

## Bulk Inserts with `executemany()`

Use `executemany()` for inserting multiple rows. PyMySQL batches the statements up to `Cursor.max_stmt_length` (1 MB) for efficiency.

```python
records = [
    ("alice@example.com", "hash1"),
    ("bob@example.com", "hash2"),
]

with connection.cursor() as cursor:
    cursor.execute("TRUNCATE TABLE staging_users")
    cursor.executemany(
        "INSERT INTO users (email, password_hash) VALUES (%s, %s)",
        records,
    )
connection.commit()
```

## Fetching Rows

| Method | Returns | Notes |
|---|---|---|
| `fetchone()` | single row or `None` | Efficient for single-row lookups |
| `fetchmany(size)` | list of rows | Page through results |
| `fetchall()` | list of all rows | Avoid on large result sets |

```python
cursor.execute("SELECT id, name FROM users WHERE id = %s", (user_id,))
row = cursor.fetchone()
if row is None:
    raise ValueError(f"User {user_id} not found")
```

## Error Handling

Catch PyMySQL exceptions from `pymysql.err`:

```python
import pymysql.err

try:
    with connection.cursor() as cursor:
        cursor.execute(sql, args)
    connection.commit()
except pymysql.err.IntegrityError as exc:
    connection.rollback()
    # duplicate key, foreign key violation, etc.
    raise
except pymysql.err.OperationalError as exc:
    # connection dropped, timeout, server gone away
    raise
except pymysql.err.ProgrammingError as exc:
    # bad SQL syntax, wrong number of params
    raise
```

Key exception classes:

- `pymysql.err.IntegrityError` — constraint violations (duplicate key, FK)
- `pymysql.err.OperationalError` — connection / server errors
- `pymysql.err.ProgrammingError` — SQL syntax errors, wrong param count
- `pymysql.err.DataError` — invalid data for column type
- `pymysql.err.DatabaseError` — base class for all DB errors

## Connection Health Check

Use `connection.ping(reconnect=True)` to check liveness before executing queries in long-lived connections (e.g., background workers):

```python
connection.ping(reconnect=True)
with connection.cursor() as cursor:
    cursor.execute(query)
```

## Reading Config from `my.cnf`

Avoid hardcoding credentials. Use `read_default_file` to read from a MySQL option file:

```python
connection = pymysql.connect(
    read_default_file="~/.my.cnf",
    read_default_group="client",
    database="mydb",
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
```

`~/.my.cnf` example:

```ini
[client]
host     = db.internal
user     = app_user
password = secret
```

## Quick Reference

```python
import pymysql
import pymysql.cursors

# Connect
conn = pymysql.connect(
    host="localhost", user="u", password="p", database="db",
    charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
)

# Query
with conn.cursor() as cur:
    cur.execute("SELECT * FROM t WHERE id = %s", (1,))
    row = cur.fetchone()

# Write + commit
with conn.cursor() as cur:
    cur.execute("INSERT INTO t (col) VALUES (%s)", ("val",))
conn.commit()

# Bulk insert
with conn.cursor() as cur:
    cur.executemany("INSERT INTO t (a, b) VALUES (%s, %s)", rows)
conn.commit()

conn.close()
```

## Additional Resources

For detailed patterns and advanced usage, consult:

- **`references/connection-patterns.md`** — Connection pooling, SSL/TLS configuration, timeout tuning, `my.cnf` patterns
- **`references/cursor-guide.md`** — Cursor type selection, streaming large result sets, stored procedures, `mogrify` debugging
