# Connection Patterns

Deep-dive reference for PyMySQL connection configuration, pooling, SSL/TLS, and long-lived connection patterns.

## Table of Contents

- [Connection Pooling](#connection-pooling)
- [SSL / TLS Configuration](#ssl--tls-configuration)
- [Timeout Tuning](#timeout-tuning)
- [Option File (my.cnf) Patterns](#option-file-mycnf-patterns)
- [Deferred Connect](#deferred-connect)
- [Unix Socket Connections](#unix-socket-connections)
- [Character Set and Collation](#character-set-and-collation)

---

## Connection Pooling

PyMySQL has no built-in connection pool. Use a third-party pool from the options below.

### DBUtils (PersistentDB / PooledDB)

`dbutils` is the most common choice for threaded applications.

```bash
pip install dbutils
```

```python
from dbutils.pooled_db import PooledDB
import pymysql
import pymysql.cursors

pool = PooledDB(
    creator=pymysql,
    maxconnections=10,      # max connections in pool (0 = unlimited)
    mincached=2,            # connections to open at startup
    maxcached=5,            # max idle connections kept in pool
    maxshared=0,            # 0 = no sharing (safest for PyMySQL)
    blocking=True,          # block when pool exhausted (True) vs raise error (False)
    host="localhost",
    user="app_user",
    password="secret",
    database="mydb",
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)

def get_connection():
    return pool.connection()

# Usage
conn = get_connection()
try:
    with conn.cursor() as cur:
        cur.execute("SELECT 1")
    conn.commit()
finally:
    conn.close()  # returns connection to pool, does not actually close it
```

### SQLAlchemy Connection Pool (recommended for larger apps)

If using SQLAlchemy, configure its pool and pass `pymysql` as the dialect driver:

```python
from sqlalchemy import create_engine

engine = create_engine(
    "mysql+pymysql://user:password@localhost/mydb?charset=utf8mb4",
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,   # runs "SELECT 1" before handing out connections
    pool_recycle=1800,    # recycle connections after 30 min (avoids "server has gone away")
)
```

`pool_pre_ping=True` is the SQLAlchemy equivalent of `connection.ping(reconnect=True)`.

---

## SSL / TLS Configuration

### Connecting with SSL

Pass SSL certificate paths directly to `pymysql.connect()`:

```python
connection = pymysql.connect(
    host="db.example.com",
    user="app_user",
    password="secret",
    database="mydb",
    charset="utf8mb4",
    ssl_ca="/etc/ssl/certs/ca-cert.pem",
    ssl_cert="/etc/ssl/certs/client-cert.pem",
    ssl_key="/etc/ssl/private/client-key.pem",
    ssl_verify_cert=True,
    ssl_verify_identity=True,
)
```

### Using an ssl.SSLContext

Pass a pre-built `ssl.SSLContext` via the `ssl` parameter for full control:

```python
import ssl
import pymysql

ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile="/path/to/ca.pem")
ctx.load_cert_chain(certfile="/path/to/client.pem", keyfile="/path/to/client-key.pem")

connection = pymysql.connect(
    host="db.example.com",
    user="app_user",
    password="secret",
    database="mydb",
    charset="utf8mb4",
    ssl=ctx,
)
```

### Disabling SSL (development only)

```python
connection = pymysql.connect(
    ...,
    ssl_disabled=True,  # never use in production
)
```

---

## Timeout Tuning

| Parameter | What it controls | Recommended value |
|---|---|---|
| `connect_timeout` | Seconds to wait when opening the TCP connection | `5`–`10` |
| `read_timeout` | Seconds to wait for data from server | `30`–`60` |
| `write_timeout` | Seconds to wait when sending data to server | `30`–`60` |

Set all three for production services to avoid hung connections:

```python
connection = pymysql.connect(
    host="localhost",
    user="u",
    password="p",
    database="db",
    charset="utf8mb4",
    connect_timeout=5,
    read_timeout=30,
    write_timeout=30,
)
```

Pair with MySQL server-side `wait_timeout` and `interactive_timeout` settings. If the server recycles idle connections (typically after 8 hours by default), use `connection.ping(reconnect=True)` before executing queries in long-lived processes.

---

## Option File (my.cnf) Patterns

Store credentials outside of source code using MySQL option files.

### `~/.my.cnf` (developer workstation)

```ini
[client]
host     = localhost
port     = 3306
user     = dev_user
password = dev_password
```

### `/etc/mysql/app.cnf` (server/CI)

```ini
[app]
host     = db.internal
port     = 3306
user     = app_user
password = prod_secret
```

### Connecting with an option file

```python
connection = pymysql.connect(
    read_default_file="/etc/mysql/app.cnf",
    read_default_group="app",     # reads [app] section
    database="mydb",
    charset="utf8mb4",
    cursorclass=pymysql.cursors.DictCursor,
)
```

`read_default_file` values override any parameter explicitly passed to `connect()` only when those parameters are absent. Explicit keyword arguments take priority.

---

## Deferred Connect

Use `defer_connect=True` to construct a `Connection` object without immediately opening the socket. Call `connection.connect()` explicitly when ready.

```python
connection = pymysql.connect(
    host="localhost",
    user="u",
    password="p",
    database="db",
    charset="utf8mb4",
    defer_connect=True,
)

# ... later, e.g., after app startup completes ...
connection.connect()
```

Check liveness with the `connection.open` property (returns `True` when connected).

---

## Unix Socket Connections

When the application and MySQL server run on the same host, a Unix socket is faster than TCP:

```python
connection = pymysql.connect(
    unix_socket="/var/run/mysqld/mysqld.sock",
    user="u",
    password="p",
    database="db",
    charset="utf8mb4",
)
```

Omit `host` and `port` when using `unix_socket`.

---

## Character Set and Collation

Always set `charset="utf8mb4"` to handle the full Unicode range (including emoji). The older `utf8` alias in MySQL is a 3-byte subset and silently drops 4-byte codepoints.

Optionally specify collation:

```python
connection = pymysql.connect(
    ...,
    charset="utf8mb4",
    collation="utf8mb4_unicode_ci",   # or utf8mb4_0900_ai_ci for MySQL 8+
)
```

To change character set on an existing connection:

```python
connection.set_character_set("utf8mb4", "utf8mb4_unicode_ci")
```

The deprecated `set_charset()` method only accepts the charset name; use `set_character_set()` instead.
