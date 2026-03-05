# aiomysql Connection Pool — Reference

## Table of Contents

1. [Pool Creation Parameters](#pool-creation-parameters)
2. [Pool Sizing Guidelines](#pool-sizing-guidelines)
3. [pool_recycle and Stale Connections](#pool_recycle-and-stale-connections)
4. [Acquiring and Releasing Connections](#acquiring-and-releasing-connections)
5. [Graceful Shutdown](#graceful-shutdown)
6. [Single Connection vs. Pool](#single-connection-vs-pool)
7. [FastAPI / Starlette Integration Pattern](#fastapi--starlette-integration-pattern)
8. [Connection Properties](#connection-properties)
9. [Troubleshooting](#troubleshooting)

---

## Pool Creation Parameters

`aiomysql.create_pool()` accepts all `aiomysql.connect()` parameters plus:

```python
pool = await aiomysql.create_pool(
    # MySQL connection parameters
    host="127.0.0.1",
    port=3306,
    user="appuser",
    password="secret",
    db="mydb",
    charset="utf8mb4",
    connect_timeout=10,       # seconds to wait for initial connect
    init_command="SET SESSION time_zone = '+00:00'",  # run on each new connection

    # Pool parameters
    minsize=2,                # connections pre-created at startup
    maxsize=20,               # hard ceiling; callers block beyond this
    pool_recycle=1800,        # recycle connections older than 30 min
    autocommit=False,         # explicit commit required; True for read-only pools
    echo=False,               # set True to log every SQL statement (debug only)
)
```

### Required vs. Optional

| Parameter | Required | Notes |
|---|---|---|
| `host` | Yes | IP or hostname |
| `user` | Yes | Database user |
| `password` | Yes | Can be empty string |
| `db` | No | Can be set per-connection via `conn.select_db()` |
| `minsize` | No | Default `1` |
| `maxsize` | No | Default `10` |
| `pool_recycle` | No | Default `-1` (disabled) |
| `charset` | No | Strongly recommended: `utf8mb4` |

---

## Pool Sizing Guidelines

Oversized pools waste database file descriptors; undersized pools create queuing latency.

**Formula**: `maxsize = (expected_concurrent_queries × avg_query_duration_ms) / 1000`

For a service expecting 50 concurrent users, each holding a query for ~20 ms:

```
maxsize = (50 × 20) / 1000 = 1 connection
```

In practice, add headroom and account for bursts:

| Traffic Profile | Suggested `minsize` | Suggested `maxsize` |
|---|---|---|
| Low (dev / staging) | 1–2 | 5 |
| Medium web service | 2–5 | 15–20 |
| High-throughput API | 5–10 | 30–50 |
| Background workers | 1 | 3–5 |

**Rule**: `maxsize` should never exceed `max_connections / number_of_app_instances` on the MySQL server side.

---

## pool_recycle and Stale Connections

MySQL closes idle connections after `wait_timeout` (default 28800 s / 8 h). If the pool holds a connection across this boundary, the next query raises `OperationalError: (2006, 'MySQL server has gone away')`.

Set `pool_recycle` to a value **shorter** than the server's `wait_timeout`:

```python
pool = await aiomysql.create_pool(
    ...,
    pool_recycle=3600,   # 1 h < server's default 8 h
)
```

Check server timeout:

```sql
SHOW VARIABLES LIKE 'wait_timeout';
```

For cloud-managed MySQL (AWS RDS, Cloud SQL) that may have shorter idle timeouts (~300–600 s), set `pool_recycle` accordingly:

```python
pool_recycle=240,   # 4 min for RDS default 5-min idle timeout
```

The `pool_recycle` counter starts from the moment the connection was created, not from last use. Connections older than the configured duration are closed and replaced when returned to the pool.

---

## Acquiring and Releasing Connections

### Context Manager (recommended)

```python
async with pool.acquire() as conn:
    async with conn.cursor() as cur:
        await cur.execute("SELECT 1")
        result = await cur.fetchone()
# conn automatically released back to pool on exit
```

### Manual Acquire/Release

Use this pattern only when the connection lifetime spans multiple `await` points in a complex flow:

```python
conn = await pool.acquire()
try:
    async with conn.cursor() as cur:
        await cur.execute("INSERT INTO events (type) VALUES (%s)", ("login",))
    await conn.commit()
finally:
    pool.release(conn)   # synchronous; safe to call in finally
```

Note: `pool.release()` is **not** a coroutine. Call it without `await`.

### Pool Status

```python
print(pool.size)      # total connections (used + free)
print(pool.freesize)  # idle connections available immediately
print(pool.minsize)   # configured minimum
print(pool.maxsize)   # configured maximum
```

---

## Graceful Shutdown

Always close the pool cleanly to avoid dangling connections on the database side.

```python
async def shutdown(pool: aiomysql.Pool) -> None:
    pool.close()              # marks all connections for close; NOT a coroutine
    await pool.wait_closed()  # waits until all connections are actually closed
```

Optionally use `pool.terminate()` to force-close all connections including ones currently in use (useful for hard shutdown):

```python
pool.terminate()
await pool.wait_closed()
```

---

## Single Connection vs. Pool

| Scenario | Use |
|---|---|
| Short CLI scripts | `aiomysql.connect()` |
| Unit/integration tests (single test) | `aiomysql.connect()` |
| Web services, APIs | `aiomysql.create_pool()` |
| Background workers | `aiomysql.create_pool()` (even with `maxsize=1`) |
| Multiple concurrent async tasks | `aiomysql.create_pool()` mandatory |

Single `connect()` is **not safe** to share across concurrent coroutines — interleaved queries on a single connection corrupt the protocol framing.

---

## FastAPI / Starlette Integration Pattern

Store the pool on the application state and create/destroy it using lifespan events:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
import aiomysql

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await aiomysql.create_pool(
        host="127.0.0.1", user="appuser",
        password="secret", db="mydb",
        minsize=2, maxsize=20,
        charset="utf8mb4", pool_recycle=3600,
    )
    yield
    app.state.pool.close()
    await app.state.pool.wait_closed()

app = FastAPI(lifespan=lifespan)

@app.get("/users/{user_id}")
async def get_user(user_id: int, request: Request):
    async with request.app.state.pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, name, email FROM users WHERE id = %s", (user_id,)
            )
            return await cur.fetchone()
```

---

## Connection Properties

After acquiring a connection, these read-only properties are available:

```python
conn.host          # MySQL server hostname/IP
conn.port          # TCP port
conn.db            # current database name
conn.user          # connected user
conn.charset       # character set for the connection
conn.encoding      # Python encoding string (e.g., "utf-8")
conn.echo          # True if SQL logging is enabled
conn.closed        # True if connection is closed
conn.get_autocommit()  # current autocommit status (bool)
```

Change the active database at runtime:

```python
await conn.select_db("other_db")
```

Toggle autocommit for a specific connection without affecting the pool default:

```python
await conn.autocommit(True)
```

---

## Troubleshooting

### `OperationalError: (2006, 'MySQL server has gone away')`

The server closed an idle connection. Fix: set `pool_recycle` to less than the server's `wait_timeout`.

### `OperationalError: (1040, 'Too many connections')`

The pool's `maxsize` exceeds MySQL's `max_connections`. Fix: reduce `maxsize` or increase `max_connections` on the server.

### Pool exhaustion — tasks hang indefinitely

All `maxsize` connections are in use. Fix: increase `maxsize`, optimize query duration, or add a timeout:

```python
import asyncio

async with asyncio.timeout(5.0):  # Python 3.11+
    async with pool.acquire() as conn:
        ...
```

### `UnicodeDecodeError` on emoji / special characters

Missing `charset="utf8mb4"` on the pool. The MySQL column must also be `utf8mb4`. Fix: set `charset="utf8mb4"` in `create_pool()`.

### SSL/TLS for cloud databases

Pass an `ssl` context to enforce encrypted connections:

```python
import ssl

ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = True
ssl_ctx.verify_mode = ssl.CERT_REQUIRED

pool = await aiomysql.create_pool(
    host="db.example.com",
    user="appuser", password="secret", db="mydb",
    ssl=ssl_ctx,
    charset="utf8mb4",
)
```
