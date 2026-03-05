# aiomysql Transactions and Cursors — Reference

## Table of Contents

1. [Transaction Basics](#transaction-basics)
2. [Isolation Levels](#isolation-levels)
3. [SAVEPOINT / Nested Transactions](#savepoint--nested-transactions)
4. [Cursor Type Comparison](#cursor-type-comparison)
5. [SSCursor — Streaming Large Results](#sscursor--streaming-large-results)
6. [DictCursor — Named Column Access](#dictcursor--named-column-access)
7. [callproc — Stored Procedures](#callproc--stored-procedures)
8. [Cursor Attributes Reference](#cursor-attributes-reference)
9. [aiomysql.sa Transactions](#aiomysqlsa-transactions)
10. [Patterns to Avoid](#patterns-to-avoid)

---

## Transaction Basics

aiomysql defaults to `autocommit=False`. Every connection starts in a transaction that must be explicitly committed or rolled back.

### Context-Manager Pattern (recommended)

```python
async with pool.acquire() as conn:
    async with conn.cursor() as cur:
        try:
            await conn.begin()
            await cur.execute(
                "INSERT INTO audit_log (action, user_id) VALUES (%s, %s)",
                ("login", user_id),
            )
            await cur.execute(
                "UPDATE users SET last_login = NOW() WHERE id = %s",
                (user_id,),
            )
            await conn.commit()
        except Exception:
            await conn.rollback()
            raise
```

### Using `autocommit=True`

Set `autocommit=True` for read-only workloads or when each statement should commit independently. Avoids holding open transactions on the server.

```python
read_pool = await aiomysql.create_pool(
    ...,
    autocommit=True,   # each statement auto-commits; no explicit commit needed
)

async with read_pool.acquire() as conn:
    async with conn.cursor(aiomysql.DictCursor) as cur:
        await cur.execute("SELECT * FROM products WHERE active = 1")
        return await cur.fetchall()
```

### Checking and Toggling Autocommit

```python
status = conn.get_autocommit()   # returns bool
await conn.autocommit(False)     # disable for this connection instance
```

---

## Isolation Levels

MySQL's default isolation level is `REPEATABLE READ`. Set it per-connection via `init_command` or a raw statement after acquiring.

```python
# Set globally via pool init_command
pool = await aiomysql.create_pool(
    ...,
    init_command="SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED",
)

# Or per-connection after acquire
async with pool.acquire() as conn:
    async with conn.cursor() as cur:
        await cur.execute(
            "SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE"
        )
    async with conn.cursor() as cur:
        await conn.begin()
        await cur.execute("SELECT balance FROM accounts WHERE id = %s FOR UPDATE", (1,))
        # ... perform work ...
        await conn.commit()
```

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Use case |
|---|---|---|---|---|
| `READ UNCOMMITTED` | Yes | Yes | Yes | Monitoring / approximate counts |
| `READ COMMITTED` | No | Yes | Yes | Most OLTP reads |
| `REPEATABLE READ` | No | No | Yes (MySQL mitigates) | Default; consistent snapshots |
| `SERIALIZABLE` | No | No | No | Financial / strict consistency |

---

## SAVEPOINT / Nested Transactions

Use SAVEPOINTs when a sub-operation should be rolled back without aborting the entire transaction. Only available through `aiomysql.sa`.

```python
from aiomysql.sa import create_engine

async with engine.acquire() as conn:
    async with conn.begin() as outer_tx:
        await conn.execute(orders.insert().values(user_id=1, total=100.0))

        # attempt an optional bonus — roll back only this part on failure
        async with conn.begin_nested() as sp:
            try:
                await conn.execute(bonuses.insert().values(user_id=1, amount=10.0))
                await sp.commit()  # releases the SAVEPOINT
            except Exception:
                await sp.rollback()  # ROLLBACK TO SAVEPOINT; outer tx survives

        await outer_tx.commit()   # commits the order regardless of bonus outcome
```

With bare `aiomysql` (no `.sa`), issue SAVEPOINT statements directly:

```python
async with conn.cursor() as cur:
    await conn.begin()
    await cur.execute("SAVEPOINT sp1")
    try:
        await cur.execute("INSERT INTO ...", (...))
    except Exception:
        await cur.execute("ROLLBACK TO SAVEPOINT sp1")
    else:
        await cur.execute("RELEASE SAVEPOINT sp1")
    await conn.commit()
```

---

## Cursor Type Comparison

| Feature | `Cursor` | `DictCursor` | `SSCursor` | `SSDictCursor` |
|---|---|---|---|---|
| Row format | tuple | dict | tuple | dict |
| Buffering | Client-side (all rows fetched) | Client-side | Server-side (row by row) | Server-side |
| Memory usage | O(result size) | O(result size) | O(1) | O(1) |
| Backward scroll | Yes | Yes | No | No |
| `rowcount` reliable | Yes | Yes | No | No |
| Best for | Small/medium queries | Readable code | Large exports | Large exports + names |

### Choosing the right cursor

- Default `Cursor`: general queries where results fit comfortably in memory.
- `DictCursor`: any query where column-name access improves readability.
- `SSCursor` / `SSDictCursor`: result sets with thousands of rows or when memory is constrained. The server holds the result set open; **do not acquire another cursor on the same connection** while streaming.

---

## SSCursor — Streaming Large Results

SSCursor fetches rows one-at-a-time from the server, holding the result set open on the server side.

```python
async with pool.acquire() as conn:
    async with conn.cursor(aiomysql.SSCursor) as cur:
        await cur.execute("SELECT id, payload FROM events WHERE created_at > %s", (since,))
        async for row in cur:           # row is a tuple
            await process_event(row[0], row[1])
        # cursor auto-closed on context manager exit
```

**Constraints when using SSCursor**:

- Do not create another cursor on the same connection while the SSCursor is open — the connection is blocked by the open result set.
- Forward-only: `cur.scroll()` on SSCursor advances row-by-row, making large skips expensive.
- `cur.rowcount` returns `-1` because the total count is unknown until all rows are consumed.

For paginated streaming, prefer `fetchmany()`:

```python
async with conn.cursor(aiomysql.SSCursor) as cur:
    await cur.execute("SELECT * FROM large_table")
    while True:
        rows = await cur.fetchmany(size=1000)
        if not rows:
            break
        await bulk_process(rows)
```

---

## DictCursor — Named Column Access

DictCursor returns each row as a `dict[str, Any]`, keyed by column name.

```python
async with conn.cursor(aiomysql.DictCursor) as cur:
    await cur.execute(
        "SELECT u.id, u.name, u.email, r.name AS role "
        "FROM users u JOIN roles r ON u.role_id = r.id "
        "WHERE u.id = %s",
        (user_id,),
    )
    row = await cur.fetchone()
    if row:
        print(row["name"], row["email"], row["role"])
```

**Custom dict type**: subclass `DictCursor` to use an `AttrDict` or dataclass-like row:

```python
class AttrDict(dict):
    def __getattr__(self, name: str):
        return self.get(name)

class AttrDictCursor(aiomysql.DictCursor):
    dict_type = AttrDict

async with conn.cursor(AttrDictCursor) as cur:
    await cur.execute("SELECT id, name FROM users WHERE id = %s", (1,))
    row = await cur.fetchone()
    print(row.name)   # attribute access
```

---

## callproc — Stored Procedures

`callproc()` executes a stored procedure. Retrieve the result set with `fetchone()` / `fetchall()` after calling.

```python
async with conn.cursor() as cur:
    # call stored procedure
    await cur.callproc("calculate_monthly_revenue", [year, month])
    rows = await cur.fetchall()

    # advance past implicit empty result set created by MySQL
    while await cur.nextset():
        pass
```

Retrieve OUT/INOUT parameters via server variables after all result sets are consumed:

```python
await cur.callproc("get_user_stats", [user_id, 0, 0])  # last two are OUT
while await cur.nextset():
    pass
await cur.execute("SELECT @_get_user_stats_1, @_get_user_stats_2")
out_vals = await cur.fetchone()
```

---

## Cursor Attributes Reference

| Attribute | Type | Description |
|---|---|---|
| `cur.description` | `tuple \| None` | Column metadata (name, type_code, …); `None` if no query run |
| `cur.rowcount` | `int` | Rows affected/produced by last DML; `-1` if unknown |
| `cur.rownumber` | `int \| None` | 0-based current row index in result set |
| `cur.lastrowid` | `int \| None` | AUTO_INCREMENT value from last INSERT/UPDATE |
| `cur.arraysize` | `int` | Default fetch size for `fetchmany()`; default `1` |
| `cur.closed` | `bool` | `True` if cursor has been closed |
| `cur.connection` | `Connection` | Back-reference to the owning connection |

Change `arraysize` to control default batch size for `fetchmany()`:

```python
cur.arraysize = 500
rows = await cur.fetchmany()   # fetches 500 rows (no size argument needed)
```

---

## aiomysql.sa Transactions

`SAConnection.begin()` returns a `Transaction` object that supports context-manager use:

```python
async with engine.acquire() as conn:
    async with conn.begin() as tx:
        await conn.execute(users.insert().values(name="Alice"))
        await conn.execute(orders.insert().values(user_id=1, total=50.0))
        # tx.commit() called automatically on clean exit
        # tx.rollback() called automatically on exception
```

`Transaction.commit()` has effect only when called on the outermost `Transaction`. Inner `.commit()` calls on the same connection are no-ops:

```python
outer = await conn.begin()
inner = await conn.begin()    # "nested" — emulated, not a SAVEPOINT
await inner.commit()           # no-op
await outer.commit()           # actually commits
```

Use `begin_nested()` for true SAVEPOINT semantics (see [SAVEPOINT section](#savepoint--nested-transactions)).

---

## Patterns to Avoid

**Opening multiple cursors on the same connection concurrently**: cursors from the same connection share the connection state. Interleaved execution corrupts results.

```python
# WRONG — two cursors on the same connection used concurrently
cur1 = await conn.cursor()
cur2 = await conn.cursor()
await asyncio.gather(
    cur1.execute("SELECT ..."),
    cur2.execute("SELECT ..."),   # will corrupt protocol state
)
```

Acquire separate connections from the pool for concurrent queries instead.

**Forgetting `await cur.nextset()` after `callproc`**: MySQL always generates an implicit empty result set after a procedure call. Failing to consume it will cause subsequent queries on the connection to fail.

**Relying on `rowcount` for SELECT**: `rowcount` reports rows produced only for DML statements. For SELECT, it reflects rows fetched so far, not total available rows.

**Re-using a closed cursor**: after `await cur.close()`, the cursor is invalid. Always create a new cursor via `async with conn.cursor() as cur`.

**Not calling `pool.wait_closed()` after `pool.close()`**: `pool.close()` marks connections for closure but does not wait for them to actually close. Without `wait_closed()`, the application may exit with open sockets.
