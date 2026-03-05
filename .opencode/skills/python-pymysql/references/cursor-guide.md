# Cursor Guide

Detailed reference for PyMySQL cursor types, fetch strategies, bulk operations, stored procedures, and query debugging.

## Table of Contents

- [Cursor Type Selection](#cursor-type-selection)
- [Buffered vs. Unbuffered Cursors](#buffered-vs-unbuffered-cursors)
- [Fetch Strategies](#fetch-strategies)
- [Bulk Operations](#bulk-operations)
- [Stored Procedures](#stored-procedures)
- [Debugging with mogrify()](#debugging-with-mogrify)
- [Row Count and Last Insert ID](#row-count-and-last-insert-id)
- [Multi-Statement and nextset()](#multi-statement-and-nextset)

---

## Cursor Type Selection

| Class | Row type | Buffered | Best for |
|---|---|---|---|
| `Cursor` | `tuple` | Yes | Default; low-memory, small-to-medium queries |
| `DictCursor` | `dict` | Yes | Readable column-name access; JSON serialization |
| `SSCursor` | `tuple` | No (server-side) | Large result sets; avoids OOM |
| `SSDictCursor` | `dict` | No (server-side) | Large result sets with named columns |

Set the default at connection time or override per cursor:

```python
import pymysql
import pymysql.cursors

# Global default for connection
conn = pymysql.connect(
    ...,
    cursorclass=pymysql.cursors.DictCursor,
)

# Override for a single cursor
with conn.cursor(pymysql.cursors.SSCursor) as cur:
    cur.execute("SELECT * FROM large_table")
    for row in cur:
        process(row)
```

---

## Buffered vs. Unbuffered Cursors

### Buffered (`Cursor`, `DictCursor`)

- All rows fetched from the server and held in client memory immediately after `execute()`.
- Safe to execute new queries on the same connection before exhausting rows.
- `len(cursor.fetchall())` works and returns total row count.

### Unbuffered (`SSCursor`, `SSDictCursor`)

- Rows are read from the server one at a time as the client calls `fetchone()` or iterates.
- **Significantly lower memory usage** for large result sets.
- Restrictions:
  - Cannot execute another query on the same connection until all rows are consumed or `cursor.close()` is called.
  - Scrolling backward is not supported.
  - `rowcount` is unavailable until all rows are read.

```python
# Streaming large export
with conn.cursor(pymysql.cursors.SSCursor) as cur:
    cur.execute("SELECT id, payload FROM events WHERE created_at > %s", (since,))
    for row in cur:           # row is a tuple
        write_to_file(row)
    # All rows consumed — safe to use conn again
```

Use `cursor.fetchall_unbuffered()` (generator) instead of `fetchall()` on `SSCursor` to avoid loading all rows into a list:

```python
with conn.cursor(pymysql.cursors.SSCursor) as cur:
    cur.execute("SELECT * FROM logs")
    for row in cur.fetchall_unbuffered():   # generator
        process(row)
```

---

## Fetch Strategies

### fetchone()

Returns one row or `None` when no rows remain. Most efficient for single-row lookups.

```python
cur.execute("SELECT email FROM users WHERE id = %s", (user_id,))
row = cur.fetchone()
if row is None:
    raise LookupError(f"No user with id={user_id}")
email = row["email"]  # DictCursor
```

### fetchmany(size)

Returns up to `size` rows as a list. Useful for pagination or chunk processing.

```python
cur.execute("SELECT id, data FROM records ORDER BY id")
while True:
    chunk = cur.fetchmany(500)
    if not chunk:
        break
    process_chunk(chunk)
```

### fetchall()

Returns all remaining rows as a list. Convenient for small tables; avoid for large ones.

```python
cur.execute("SELECT * FROM config")
settings = {row["key"]: row["value"] for row in cur.fetchall()}
```

---

## Bulk Operations

### executemany() for INSERT / REPLACE

PyMySQL batches rows into multi-row `INSERT` statements up to `Cursor.max_stmt_length` (1 MB by default), making it significantly faster than looping with `execute()`.

```python
users = [
    ("alice@example.com", "hashed_pw_1"),
    ("bob@example.com",   "hashed_pw_2"),
    ("carol@example.com", "hashed_pw_3"),
]

with conn.cursor() as cur:
    cur.executemany(
        "INSERT INTO users (email, password_hash) VALUES (%s, %s)",
        users,
    )
conn.commit()
```

`executemany()` also works with `UPDATE` and `DELETE`, though there is no batching benefit — it loops internally for those statements.

### Increasing Batch Size

If rows are large, raise `max_stmt_length`:

```python
with conn.cursor() as cur:
    cur.max_stmt_length = 4 * 1024 * 1024  # 4 MB
    cur.executemany("INSERT INTO ...", large_batch)
conn.commit()
```

Ensure the MySQL server's `max_allowed_packet` matches or exceeds this value.

### INSERT … ON DUPLICATE KEY UPDATE (upsert)

```python
with conn.cursor() as cur:
    cur.executemany(
        """
        INSERT INTO inventory (sku, qty)
        VALUES (%s, %s)
        ON DUPLICATE KEY UPDATE qty = VALUES(qty)
        """,
        inventory_rows,
    )
conn.commit()
```

---

## Stored Procedures

Call stored procedures with `cursor.callproc(name, args)`.

```python
with conn.cursor() as cur:
    cur.callproc("calculate_totals", (order_id,))
    # callproc creates an implicit empty result set; advance past it
    cur.nextset()
    result = cur.fetchall()
```

### Retrieving OUT / INOUT Parameters

PyMySQL stores modified OUT/INOUT parameters in server variables named `@_procname_n`. Retrieve them after consuming all result sets:

```python
with conn.cursor(pymysql.cursors.DictCursor) as cur:
    cur.callproc("get_user_stats", (user_id, 0, 0))  # last two are OUT params
    # exhaust result sets
    while cur.nextset():
        pass
    # retrieve OUT params
    cur.execute(
        "SELECT @_get_user_stats_1 AS login_count, @_get_user_stats_2 AS order_count"
    )
    out_params = cur.fetchone()
```

> **Warning**: `callproc()` always generates an empty result set before any result sets from the procedure itself. Always call `cursor.nextset()` to advance past it before fetching data.

---

## Debugging with mogrify()

`cursor.mogrify(query, args)` returns the final SQL string after parameter substitution, without executing it. Use during development to verify query construction.

```python
with conn.cursor() as cur:
    query = "SELECT * FROM orders WHERE user_id = %s AND status = %s"
    args = (42, "pending")
    print(cur.mogrify(query, args))
    # Output: SELECT * FROM orders WHERE user_id = 42 AND status = 'pending'
    cur.execute(query, args)
```

`mogrify()` follows the Psycopg DB API extension. The returned string is for debugging only — do not pass it back to `execute()` (that would bypass parameterization).

---

## Row Count and Last Insert ID

### Affected / matched rows

```python
with conn.cursor() as cur:
    n = cur.execute("UPDATE users SET active = 0 WHERE last_login < %s", (cutoff,))
    print(f"{n} rows updated")
    # cursor.rowcount is also available
    print(cur.rowcount)
```

### Last inserted auto-increment ID

```python
with conn.cursor() as cur:
    cur.execute("INSERT INTO items (name) VALUES (%s)", ("widget",))
    new_id = cur.lastrowid
conn.commit()
```

`lastrowid` reflects the `LAST_INSERT_ID()` of the most recent INSERT on this cursor.

---

## Multi-Statement and nextset()

When a procedure or multi-query returns multiple result sets, use `cursor.nextset()` to advance through them:

```python
with conn.cursor(pymysql.cursors.DictCursor) as cur:
    cur.execute("CALL multi_result_proc(%s)", (param,))
    all_results = []
    while True:
        rows = cur.fetchall()
        if rows:
            all_results.append(rows)
        if not cur.nextset():
            break
```

`nextset()` returns `True` if there is another result set, `None` or `False` when exhausted.

> Always exhaust all result sets (including the empty one from `callproc`) before issuing the next query on the same connection. Failure to do so can cause a `Commands out of sync` error.
