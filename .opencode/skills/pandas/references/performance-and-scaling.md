# Performance and Scaling

## Table of Contents

- [Copy-on-Write Patterns](#copy-on-write-patterns)
- [Vectorization Patterns](#vectorization-patterns)
- [GroupBy Performance](#groupby-performance)
- [Scaling to Large Datasets](#scaling-to-large-datasets)
- [Numba and Cython Integration](#numba-and-cython-integration)
- [eval() and query()](#eval-and-query)
- [Anti-patterns to Avoid](#anti-patterns-to-avoid)

---

## Copy-on-Write Patterns

pandas 3.0 enforces Copy-on-Write (CoW). Understanding its mechanics eliminates unnecessary copies.

**CoW rule**: any DataFrame or Series derived from another behaves as an independent copy. Modifying it does not affect the parent — and vice versa.

### Pattern: reassign to avoid shared data

```python
# Creates shared data — setitem on df2 triggers a defensive copy
df2 = df.reset_index(drop=True)
df2["col"] = 0  # copy happens here

# No shared data — no copy needed on mutation
df = df.reset_index(drop=True)
df["col"] = 0   # operates in-place
```

Reassigning the output to the same variable invalidates the shared reference immediately.

### Pattern: method chaining

Method chaining is efficient with CoW because intermediate objects are discarded before any mutation occurs:

```python
result = (
    df
    .query("score > 50")
    .assign(grade=lambda x: pd.cut(x["score"], bins=[0, 60, 80, 100], labels=["C", "B", "A"]))
    .groupby("grade")["score"]
    .mean()
)
```

### Pattern: conditional column update

```python
# Wrong — chained assignment, raises ChainedAssignmentError in pandas 3.0
df["score"][df["active"]] = 0

# Correct — single loc statement
df.loc[df["active"], "score"] = 0

# Correct — where for conditional replacement
df["score"] = df["score"].where(~df["active"], other=0)
```

---

## Vectorization Patterns

### Replace apply/loop with built-in methods

```python
# Slow: row-wise apply with Python function
df["total"] = df.apply(lambda row: row["qty"] * row["price"], axis=1)

# Fast: vectorized arithmetic
df["total"] = df["qty"] * df["price"]

# Slow: conditional string classification in a loop
categories = []
for v in df["score"]:
    if v >= 90:
        categories.append("A")
    elif v >= 80:
        categories.append("B")
    else:
        categories.append("C")
df["grade"] = categories

# Fast: pd.cut or np.select
df["grade"] = pd.cut(df["score"], bins=[0, 80, 90, 100], labels=["C", "B", "A"])

# Fast: np.select for arbitrary conditions
conditions = [df["score"] >= 90, df["score"] >= 80]
choices    = ["A", "B"]
df["grade"] = np.select(conditions, choices, default="C")
```

### String operations — use .str accessor

```python
# Slow: apply with a lambda
df["domain"] = df["email"].apply(lambda e: e.split("@")[1])

# Fast: vectorized str accessor
df["domain"] = df["email"].str.split("@").str[1]

# Regex extraction
df[["area", "number"]] = df["phone"].str.extract(r"(\d{3})-(\d+)")
```

### Lookup tables — prefer map over apply

```python
lookup = {1: "low", 2: "medium", 3: "high"}

# Slow
df["label"] = df["code"].apply(lambda x: lookup.get(x, "unknown"))

# Fast
df["label"] = df["code"].map(lookup).fillna("unknown")
```

---

## GroupBy Performance

### Use named aggregation

Named aggregation (`agg(name=(col, func))`) is cleaner and avoids multi-level column headers:

```python
result = df.groupby("region").agg(
    total_sales=("amount", "sum"),
    avg_sales=("amount", "mean"),
    order_count=("order_id", "count"),
    unique_customers=("customer_id", "nunique"),
)
```

### Avoid apply in groupby for aggregations

`apply` in `groupby` is slow because it creates a new DataFrame for each group. Use `agg` or `transform` instead:

```python
# Slow — creates sub-DataFrame per group
df.groupby("region").apply(lambda g: g["amount"].sum())

# Fast — uses optimized C implementation
df.groupby("region")["amount"].sum()
```

### transform vs apply for same-shape results

```python
# Wrong: apply with aggregation doesn't broadcast back to original shape
df["region_avg"] = df.groupby("region")["amount"].apply(lambda g: g.mean())

# Correct: transform returns same-length result aligned to original index
df["region_avg"] = df.groupby("region")["amount"].transform("mean")

# Z-score normalization within group
df["z_score"] = df.groupby("region")["amount"].transform(
    lambda s: (s - s.mean()) / s.std()
)
```

---

## Scaling to Large Datasets

### Load only what is needed

```python
# CSV — specify columns and dtypes upfront
df = pd.read_csv(
    "large.csv",
    usecols=["id", "timestamp", "value"],
    dtype={"id": "int32", "value": "float32"},
    parse_dates=["timestamp"],
)

# Parquet — column predicate pushdown reads only required columns from disk
df = pd.read_parquet("large.parquet", columns=["id", "timestamp", "value"])
```

### Process in chunks

Use chunking when the dataset exceeds available memory but each chunk fits:

```python
# Process a large CSV in chunks and aggregate
counts = pd.Series(dtype=int)
for chunk in pd.read_csv("large.csv", chunksize=100_000, usecols=["category"]):
    counts = counts.add(chunk["category"].value_counts(), fill_value=0)

result = counts.astype(int).sort_values(ascending=False)
```

Chunking works well for:
- Aggregations that are commutative across chunks (sum, count, value_counts)
- File format conversion (CSV → Parquet per chunk)

Chunking does not work well for:
- Global sort, deduplication across the full dataset
- Join/merge across chunks

For those use cases, consider Dask, Polars, or DuckDB.

### Prefer Parquet over CSV for large data

| Property            | CSV                  | Parquet                         |
|---------------------|----------------------|---------------------------------|
| Column selection    | Full file scan       | Column-level read (fast)        |
| Compression         | None (unless gzipped)| Snappy/Zstd by default          |
| Dtype preservation  | No (requires re-spec)| Yes                             |
| Append              | Easy                 | Requires rewrite or partitioning|

```python
# Write with compression (default is snappy)
df.to_parquet("output.parquet", compression="zstd")

# Partitioned Parquet for even faster filtered reads
df.to_parquet("output/", partition_cols=["year", "region"])
pd.read_parquet("output/", filters=[("year", "==", 2024), ("region", "==", "EU")])
```

---

## Numba and Cython Integration

### When to use Numba

Use Numba when:
- A rolling/expanding/groupby `apply` operates on large arrays (>100k rows)
- The function involves numerical computation with loops
- Performance matters but rewriting in Cython is not practical

```python
import numba
import numpy as np

# Decorate pure-Python numeric function with @jit
@numba.jit(nopython=True)
def weighted_mean(values, weights):
    total = 0.0
    total_weight = 0.0
    for v, w in zip(values, weights):
        total += v * w
        total_weight += w
    return total / total_weight

# Pass numpy arrays via .to_numpy()
result = weighted_mean(df["value"].to_numpy(), df["weight"].to_numpy())

# Use engine="numba" for rolling/groupby apply
roll_result = df["value"].rolling(100).apply(np.sum, raw=True, engine="numba")
```

**First call is slow** (Numba compiles the function). Subsequent calls use the cached compiled version.

### pandas built-in Numba engine

Select pandas methods accept `engine="numba"`:

```python
# Rolling apply
df["roll_sum"] = df["value"].rolling(10).apply(np.sum, raw=True, engine="numba")

# GroupBy apply
df.groupby("group")["value"].rolling(10).mean(engine="numba")
```

---

## eval() and query()

`pd.eval()` and `DataFrame.eval()` evaluate expression strings using the `numexpr` engine, reducing intermediate array allocations for large DataFrames (>10,000 rows).

```python
# DataFrame.eval — avoids intermediate arrays
result = df.eval("total = qty * price - discount")

# Multiple assignments in one expression
df = df.eval("""
    subtotal = qty * price
    tax      = subtotal * 0.08
    total    = subtotal + tax
""")

# DataFrame.query — readable filtering without boilerplate
df.query("score > 80 and region == 'EU'")

# Reference local variables with @ prefix
threshold = 80
df.query("score > @threshold")
```

**When eval/query help:**
- DataFrames with >10,000 rows and multiple arithmetic/boolean operations
- Expression involves multiple columns (reduces temporary allocations)

**When eval/query don't help:**
- Small DataFrames — overhead exceeds benefit
- Operations not supported by numexpr (function calls, comprehensions)

---

## Anti-patterns to Avoid

### iterrows — never use for computation

```python
# Extremely slow — creates a Series object per row, dtype-unsafe
for idx, row in df.iterrows():
    df.at[idx, "total"] = row["qty"] * row["price"]

# Correct
df["total"] = df["qty"] * df["price"]
```

### Growing a DataFrame row by row

```python
# Extremely slow — copies entire DataFrame on each append
result = pd.DataFrame()
for record in records:
    result = pd.concat([result, pd.DataFrame([record])])

# Correct — build a list of dicts, construct DataFrame once
rows = []
for record in records:
    rows.append({"a": record.a, "b": record.b})
result = pd.DataFrame(rows)
```

### Object dtype for known-type data

```python
# Wrong — object dtype forces Python-level operations
df["code"] = df["code"].astype(object)

# Correct — use the appropriate type
df["code"] = df["code"].astype("Int32")       # nullable int
df["label"] = df["label"].astype("category")  # low-cardinality string
```

### Chained assignment

```python
# Raises ChainedAssignmentError in pandas 3.0
df[df["active"]]["score"] = 0

# Correct
df.loc[df["active"], "score"] = 0
```

### inplace=True (mostly unnecessary)

`inplace=True` does not save memory in most pandas operations. It returns `None` and mutates the object, which complicates method chaining. Prefer assignment:

```python
# Old pattern — use inplace
df.drop(columns=["tmp"], inplace=True)
df.rename(columns={"old": "new"}, inplace=True)

# Preferred — return value, chainable, CoW-compatible
df = df.drop(columns=["tmp"]).rename(columns={"old": "new"})
```

Exception: `DataFrame.sort_values(inplace=True)` and `DataFrame.reset_index(inplace=True)` are fine for one-off mutations when chaining is not needed.
