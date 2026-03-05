---
name: python-aiomysql
description: This skill should be used when the user asks to "connect to MySQL with asyncio", "use aiomysql", "set up an async MySQL connection pool", "query MySQL asynchronously in Python", or needs guidance on aiomysql best practices, connection lifecycle, transactions, or cursor types.
---

# aiomysql — Async MySQL for Python

aiomysql provides asyncio-native access to MySQL databases. It wraps PyMySQL with `async/await` support and exposes Connection, Cursor, and Pool primitives that mirror the synchronous DBAPI interface.

**Requirements**: Python 3.9+, PyMySQL. Install with:

```bash
pip install aiomysql
# Optional SQLAlchemy expression layer:
pip install aiomysql sqlalchemy
```

## Core Principles

- Always use a connection pool (`create_pool`) in production — never bare `connect()` for long-lived services.
- Always use async context managers (`async with`) to guarantee connection and cursor release.
- Never format SQL strings manually. Always pass parameters as the second argument to `execute()`.
- Commit explicitly; `autocommit` defaults to `False`.
- Close the pool cleanly on shutdown: `pool.close()` then `await pool.wait_closed()`.

## Connection Pool (Preferred Pattern)

Create one pool at application startup and share it across the lifetime of the service.

```python
import asyncio
import aiomysql

async def create_app_pool() -> aiomysql.Pool:
    return await aiomysql.create_pool(
        host="127.0.0.1",
        port=3306,
        user="appuser",
        password="secret",
        db="mydb",
        minsize=2,
        maxsize=10,
        autocommit=False,
        pool_recycle=3600,  # recycle stale connections after 1 h
        charset="utf8mb4",
    )

async def main() -> None:
    pool = await create_app_pool()
    try:
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1")
                (result,) = await cur.fetchone()
                print(result)  # 1
    finally:
        pool.close()
        await pool.wait_closed()

asyncio.run(main())
```

**Key parameters**:

| Parameter | Default | Purpose |
|---|---|---|
| `minsize` | 1 | Connections pre-created at startup |
| `maxsize` | 10 | Hard ceiling on pool size |
| `pool_recycle` | -1 (off) | Seconds before a connection is recycled |
| `autocommit` | False | Set `True` for read-only workloads |
| `charset` | `''` | Use `utf8mb4` for full Unicode support |

## Parameterized Queries — SQL Injection Prevention

Pass values as the second argument to `execute()`. Never use f-strings or `.format()` for SQL parameters.

```python
# CORRECT — parameterized
await cur.execute(
    "SELECT id, name FROM users WHERE email = %s AND active = %s",
    (email, True),
)

# CORRECT — bulk insert via executemany (batched automatically)
rows = [("Alice", "alice@example.com"), ("Bob", "bob@example.com")]
await cur.executemany(
    "INSERT INTO users (name, email) VALUES (%s, %s)",
    rows,
)

# WRONG — string interpolation, never do this
await cur.execute(f"SELECT * FROM users WHERE email = '{email}'")
```

## Cursor Types

Choose the right cursor for the job:

| Cursor | Import | Returns | Use when |
|---|---|---|---|
| `Cursor` (default) | built-in | `tuple` | General queries, small result sets |
| `DictCursor` | `aiomysql.DictCursor` | `dict` | Named-column access, readability |
| `SSCursor` | `aiomysql.SSCursor` | `tuple` | Large result sets (unbuffered) |
| `SSDictCursor` | `aiomysql.SSDictCursor` | `dict` | Large result sets, named columns |

```python
# DictCursor — access columns by name
async with conn.cursor(aiomysql.DictCursor) as cur:
    await cur.execute("SELECT id, name FROM users WHERE id = %s", (42,))
    row = await cur.fetchone()
    print(row["name"])  # "Alice"

# SSCursor — stream large result sets without buffering all rows in memory
async with conn.cursor(aiomysql.SSCursor) as cur:
    await cur.execute("SELECT * FROM large_table")
    async for row in cur:
        process(row)
```

## Transaction Management

Explicit transaction handling avoids silent data loss and partial writes.

```python
async def transfer_funds(
    pool: aiomysql.Pool, from_id: int, to_id: int, amount: float
) -> None:
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            try:
                await conn.begin()
                await cur.execute(
                    "UPDATE accounts SET balance = balance - %s WHERE id = %s",
                    (amount, from_id),
                )
                await cur.execute(
                    "UPDATE accounts SET balance = balance + %s WHERE id = %s",
                    (amount, to_id),
                )
                await conn.commit()
            except Exception:
                await conn.rollback()
                raise
```

Never rely on auto-rollback. Always call `conn.rollback()` explicitly in the `except` block when `autocommit=False`.

## Fetch Strategies

Choose the fetch method based on result size:

```python
# Single row — stops fetching immediately
row = await cur.fetchone()

# All rows — fine for small to medium result sets
rows = await cur.fetchall()

# Paginated — process in chunks to bound memory usage
while True:
    chunk = await cur.fetchmany(size=500)
    if not chunk:
        break
    process_chunk(chunk)
```

Use `SSCursor` (unbuffered) for very large result sets instead of `fetchall()`.

## Accessing INSERT IDs and Row Counts

```python
await cur.execute(
    "INSERT INTO orders (user_id, total) VALUES (%s, %s)",
    (user_id, total),
)
await conn.commit()

new_id = cur.lastrowid      # AUTO_INCREMENT value of inserted row
affected = cur.rowcount     # rows affected by last DML statement
```

## Lifecycle: Single Connection (Scripts / Tests)

Use bare `connect()` only in short-lived scripts or test fixtures — not in services.

```python
import aiomysql

async def run_script() -> None:
    conn = await aiomysql.connect(
        host="127.0.0.1", port=3306,
        user="root", password="", db="mydb",
        charset="utf8mb4",
    )
    try:
        async with conn.cursor() as cur:
            await cur.execute("SELECT VERSION()")
            (version,) = await cur.fetchone()
            print(f"MySQL {version}")
    finally:
        conn.close()  # synchronous; flushes and closes socket
```

Note: `conn.close()` is **synchronous**. Use `await conn.ensure_closed()` when you need the async variant that sends a quit command before closing.

## SQLAlchemy Expression Layer (`aiomysql.sa`)

Use `aiomysql.sa` for type-safe query construction when raw SQL becomes unwieldy.

```python
import asyncio
import sqlalchemy as sa
from aiomysql.sa import create_engine

metadata = sa.MetaData()
users = sa.Table(
    "users",
    metadata,
    sa.Column("id", sa.Integer, primary_key=True),
    sa.Column("name", sa.String(128)),
    sa.Column("email", sa.String(255)),
)

async def main() -> None:
    engine = await create_engine(
        user="appuser", password="secret",
        host="127.0.0.1", db="mydb",
    )
    async with engine.acquire() as conn:
        async with conn.begin() as tx:
            await conn.execute(users.insert().values(name="Alice", email="a@x.com"))
            await tx.commit()

        result = await conn.execute(users.select())
        async for row in result:
            print(row.id, row.name)

    engine.close()
    await engine.wait_closed()

asyncio.run(main())
```

The `SAConnection` wraps `aiomysql.Connection` and provides `.begin()`, `.begin_nested()` (SAVEPOINT), `.scalar()`, and `.execute()` with SQLAlchemy expression support.

## Common Mistakes

**Forgetting `await` on cursor close**: `cur.close()` is a coroutine — omitting `await` silently skips cleanup. Prefer `async with conn.cursor() as cur` to avoid this entirely.

**Not recycling stale connections**: Without `pool_recycle`, connections held longer than MySQL's `wait_timeout` (default 8 hours) become invalid. Set `pool_recycle` to a value shorter than the server's timeout.

**Using `fetchall()` on large tables**: Loads the entire result set into memory. Use `fetchmany(size=N)` or `SSCursor` for large datasets.

**Mixing autocommit modes**: Setting `autocommit=True` on the pool and calling `await conn.commit()` is harmless but redundant. Be explicit and consistent per workload.

**Passing `loop` parameter in Python 3.10+**: The `loop` parameter is deprecated and ignored in modern Python. Remove it from all `connect()` and `create_pool()` calls.

## Additional Resources

### Reference Files

- **`references/connection-pool.md`** — Pool configuration, `pool_recycle`, sizing guidelines, and graceful shutdown patterns
- **`references/transactions-cursors.md`** — Transaction isolation levels, SAVEPOINT nesting, cursor type comparison, and `callproc` usage

### External Documentation

- [aiomysql API Reference](https://aiomysql.readthedocs.io/en/latest/connection.html)
- [aiomysql Pool](https://aiomysql.readthedocs.io/en/latest/pool.html)
- [aiomysql Cursors](https://aiomysql.readthedocs.io/en/latest/cursors.html)
- [aiomysql.sa SQLAlchemy layer](https://aiomysql.readthedocs.io/en/latest/sa.html)
