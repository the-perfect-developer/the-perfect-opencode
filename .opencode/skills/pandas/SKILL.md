---
name: pandas
description: This skill should be used when the user asks to "use pandas", "analyze data with pandas", "work with DataFrames", "clean data with pandas", or needs guidance on pandas best practices, data manipulation, performance optimization, or common pandas patterns.
---

# pandas

pandas (v3.0+) is Python's primary library for in-memory tabular data analysis. It provides `DataFrame` and `Series` as core structures with vectorized operations, I/O adapters, groupby, merging, and time-series support.

## Core Data Structures

**DataFrame** - 2-dimensional labeled table with columns of potentially different types.

**Series** - 1-dimensional labeled array; a single column or row of a DataFrame.

```python
import pandas as pd
import numpy as np

# Create DataFrame from dict
df = pd.DataFrame({
    "name": ["Alice", "Bob", "Charlie"],
    "score": [95, 82, 78],
    "grade": pd.Categorical(["A", "B", "C"]),
})

# Create Series
s = pd.Series([10, 20, 30], index=["a", "b", "c"], name="values")
```

## Indexing and Selection

Use `.loc` (label-based) and `.iloc` (position-based) for explicit indexing.

```python
# Label-based selection
df.loc[0, "name"]               # single value
df.loc[:, ["name", "score"]]    # multiple columns
df.loc[df["score"] > 80]        # boolean mask

# Position-based selection
df.iloc[0, 1]      # row 0, col 1
df.iloc[1:3, :]    # rows 1-2, all columns
```

**Never use chained indexing** (`df["col"][condition]`). In pandas 3.0 with Copy-on-Write enabled, chained assignment raises `ChainedAssignmentError`. Always use `.loc` for conditional assignment:

```python
# Wrong — chained assignment, silently fails or raises in pandas 3.0
df["score"][df["name"] == "Bob"] = 90

# Correct
df.loc[df["name"] == "Bob", "score"] = 90
```

## Copy-on-Write (pandas 3.0 default)

Copy-on-Write (CoW) is the default behavior in pandas 3.0. Every derived object (slice, subset, result of a method) behaves as an independent copy — modifications never propagate to the parent.

**Key rule**: assign back to the same variable to avoid unnecessary copies:

```python
# Triggers a copy on every subsequent mutation (wasteful)
df2 = df.reset_index(drop=True)
df2.iloc[0, 0] = 100  # triggers copy because df and df2 share data

# Reassign to same variable — no extra copy needed
df = df.reset_index(drop=True)
df.iloc[0, 0] = 100   # operates in-place, no shared data
```

**Avoid keeping unnecessary references alive** — they prevent CoW from optimizing copies away.

## Efficient Data Types

Default dtypes are not memory-optimal. Apply the correct dtype at read time or immediately after.

| Data                   | Default dtype | Optimal dtype          |
|------------------------|---------------|------------------------|
| Low-cardinality strings | `object`/`str` | `category`            |
| Large integers         | `int64`       | `int32` / `int16`      |
| Booleans with NA       | `object`      | `boolean` (nullable)   |
| Floats                 | `float64`     | `float32`              |

```python
# Convert low-cardinality string column to Categorical (~10x memory reduction)
df["status"] = df["status"].astype("category")

# Downcast numerics
df["id"] = pd.to_numeric(df["id"], downcast="unsigned")
df["value"] = pd.to_numeric(df["value"], downcast="float")

# Check memory usage
df.memory_usage(deep=True)
```

Use `pd.Categorical` for any column with fewer than ~50% unique values relative to row count.

## Vectorized Operations

Prefer vectorized operations over explicit Python loops. Vectorized code operates on entire arrays using optimized C/NumPy code.

```python
# Wrong — Python loop, slow
results = []
for _, row in df.iterrows():
    results.append(row["x"] * row["y"])

# Correct — vectorized
df["product"] = df["x"] * df["y"]

# Use .str accessor for string operations (vectorized)
df["name_upper"] = df["name"].str.upper()
df["name_len"] = df["name"].str.len()

# Use .dt accessor for datetime operations
df["year"] = df["timestamp"].dt.year
df["month"] = df["timestamp"].dt.month
```

**Iteration order** (fastest to slowest):
1. Vectorized column operations (preferred)
2. `df.apply(func, axis=1)` with `raw=True` for numeric
3. `df.apply(func, axis=1)` — calls func per row as Series
4. `itertuples()` — avoid unless necessary
5. `iterrows()` — avoid, slowest, loses dtypes

## Missing Data

pandas uses `NaN` (float), `pd.NaT` (datetime), and `pd.NA` (nullable extension types) to represent missing values.

```python
# Detect missing
df.isna()            # boolean mask
df["col"].notna()    # inverse mask

# Fill missing values
df["score"].fillna(0)
df["score"].fillna(df["score"].median())

# Drop rows with missing values
df.dropna(subset=["score", "name"])

# Use nullable integer (preserves int type with NAs)
s = pd.array([1, 2, None], dtype="Int64")  # capital I = nullable
```

Prefer nullable extension types (`Int64`, `Float64`, `boolean`, `string`) over NumPy types when the column may contain missing values. This avoids silent upcasting to `float64`.

## GroupBy: Split-Apply-Combine

```python
# Aggregation — returns one row per group
df.groupby("grade")["score"].mean()
df.groupby("grade").agg({"score": ["mean", "std", "count"]})

# Named aggregation (pandas 0.25+)
df.groupby("grade").agg(
    avg_score=("score", "mean"),
    count=("name", "count"),
)

# Transformation — returns same shape as input
df["score_zscore"] = df.groupby("grade")["score"].transform(
    lambda s: (s - s.mean()) / s.std()
)

# Filter — keep groups matching a condition
df.groupby("grade").filter(lambda g: len(g) >= 2)
```

Avoid calling `apply` with a function that returns a scalar inside a `transform` — use `transform` directly with a named aggregation function for best performance.

## Merging and Reshaping

```python
# Merge (SQL-style join)
result = pd.merge(left, right, on="key", how="left")
result = pd.merge(left, right, left_on="id", right_on="user_id", how="inner")

# Concat along rows
pd.concat([df1, df2], ignore_index=True)

# Pivot — long to wide
pivot = df.pivot_table(index="date", columns="category", values="amount", aggfunc="sum")

# Melt — wide to long
melted = df.melt(id_vars=["id"], value_vars=["q1", "q2", "q3"], var_name="quarter")
```

Always pass `ignore_index=True` to `pd.concat` when the original indices are meaningless row numbers — prevents duplicate index values.

## I/O Best Practices

| Format   | Read                        | Write                        | Notes                        |
|----------|-----------------------------|------------------------------|------------------------------|
| CSV      | `pd.read_csv()`             | `df.to_csv(index=False)`     | Use `usecols=` to limit columns |
| Parquet  | `pd.read_parquet()`         | `df.to_parquet()`            | Preferred for large datasets |
| JSON     | `pd.read_json()`            | `df.to_json()`               | Use `orient="records"` for APIs |
| Excel    | `pd.read_excel()`           | `df.to_excel(index=False)`   | Slow; avoid for large files  |
| SQL      | `pd.read_sql(query, conn)`  | `df.to_sql(name, conn)`      | Use `chunksize=` for large writes |

```python
# Specify dtypes at read time — avoids post-hoc conversion cost
df = pd.read_csv(
    "data.csv",
    usecols=["id", "name", "amount"],
    dtype={"id": "int32", "name": "category"},
    parse_dates=["created_at"],
)

# Parquet with column selection — reads only needed columns from disk
df = pd.read_parquet("data.parquet", columns=["id", "amount"])
```

## User-Defined Functions

Minimize UDF usage. Built-in pandas/NumPy methods are always faster than custom Python functions.

When a UDF is necessary:

```python
# Use raw=True for numeric operations — passes NumPy array, not Series
df["result"] = df["value"].rolling(10).apply(np.sum, raw=True)

# Use engine="numba" for large datasets (>1M rows)
df["result"] = df["value"].rolling(10).apply(my_func, raw=True, engine="numba")

# Prefer map over apply for element-wise Series operations
df["label"] = df["code"].map({1: "low", 2: "mid", 3: "high"})
```

Never use `apply` with `axis=1` on large DataFrames when a vectorized alternative exists.

## Quick Reference

| Task                          | Method                                        |
|-------------------------------|-----------------------------------------------|
| Shape                         | `df.shape`, `len(df)`                         |
| Column dtypes                 | `df.dtypes`                                   |
| Summary statistics            | `df.describe()`                               |
| Unique values                 | `df["col"].unique()`, `df["col"].nunique()`   |
| Value counts                  | `df["col"].value_counts()`                    |
| Sort                          | `df.sort_values("col", ascending=False)`      |
| Rename columns                | `df.rename(columns={"old": "new"})`           |
| Drop columns                  | `df.drop(columns=["a", "b"])`                 |
| Reset index                   | `df.reset_index(drop=True)`                   |
| Filter rows                   | `df.query("score > 80 and grade == 'A'")`     |
| Select by dtype               | `df.select_dtypes(include="number")`          |
| Duplicate detection           | `df.duplicated()`, `df.drop_duplicates()`     |
| Apply function                | `df["col"].map(func)`                         |

## Additional Resources

### Reference Files

- **`references/data-types-and-memory.md`** - dtype selection guide, nullable types, Categorical patterns, memory profiling
- **`references/performance-and-scaling.md`** - CoW patterns, vectorization, chunking large files, Numba/Cython integration, eval()
