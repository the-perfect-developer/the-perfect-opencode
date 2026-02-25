# Data Types and Memory Optimization

## Table of Contents

- [dtype Overview](#dtype-overview)
- [Nullable Extension Types](#nullable-extension-types)
- [Categorical Data](#categorical-data)
- [Numeric Downcasting](#numeric-downcasting)
- [String Data (pandas 3.0)](#string-data-pandas-30)
- [DateTime Types](#datetime-types)
- [Memory Profiling](#memory-profiling)
- [Dtype at Read Time](#dtype-at-read-time)

---

## dtype Overview

pandas dtypes map to underlying storage types. Choosing the correct dtype reduces memory and improves computation speed.

| dtype          | Storage          | Nullable? | Use when                                  |
|----------------|------------------|-----------|-------------------------------------------|
| `int64`        | NumPy int64      | No        | Default integer; no missing values        |
| `Int64`        | Arrow / masked   | Yes       | Integer column that may have NAs          |
| `float64`      | NumPy float64    | Yes (NaN) | Default float; NaN represents missing     |
| `Float64`      | Arrow / masked   | Yes (NA)  | Float with explicit NA (no NaN semantics) |
| `bool`         | NumPy bool       | No        | Boolean flags without missing values      |
| `boolean`      | Arrow / masked   | Yes       | Boolean with NA support                   |
| `str`          | Arrow string     | Yes       | Default string in pandas 3.0              |
| `object`       | Python object    | Yes       | Avoid; fallback for mixed/unknown types   |
| `category`     | CategoricalDtype | Yes       | Low-cardinality strings or ordered enums  |
| `datetime64[ns]`| NumPy datetime  | Yes (NaT) | Timezone-naive timestamps                 |
| `datetime64[ns, tz]` | DatetimeTZ | Yes (NaT)| Timezone-aware timestamps                 |

---

## Nullable Extension Types

NumPy-backed dtypes (`int64`, `bool`) cannot hold `NaN` natively — pandas silently upcasts integers to `float64` when NAs appear. Nullable extension types (`Int64`, `boolean`, `Float64`) avoid this.

```python
# Problem: integer becomes float when NA introduced
s = pd.Series([1, 2, 3])
s[1] = np.nan
print(s.dtype)  # float64 — lost integer semantics!

# Solution: use nullable integer from the start
s = pd.Series([1, 2, None], dtype="Int64")  # capital I
print(s.dtype)  # Int64
print(s[1])     # <NA> not NaN
```

**Rules for nullable types:**

- Use `"Int8"` / `"Int16"` / `"Int32"` / `"Int64"` for integers that may contain missing values.
- Use `"Float32"` / `"Float64"` when explicit `pd.NA` is preferred over `np.nan`.
- Use `"boolean"` for boolean columns with missing values (Kleene logic for `&` / `|`).
- Use `"string"` (or `pd.StringDtype()`) for text columns — avoids `object` dtype overhead.

```python
df = pd.DataFrame({
    "count": pd.array([10, None, 30], dtype="Int32"),
    "ratio": pd.array([0.5, None, 1.5], dtype="Float32"),
    "active": pd.array([True, None, False], dtype="boolean"),
    "label": pd.array(["foo", None, "bar"], dtype="string"),
})
```

---

## Categorical Data

`category` dtype is the single most impactful optimization for low-cardinality string columns. It stores the unique values once and uses small integers as codes.

**When to use Categorical:**

- Columns with fewer than ~50% unique values relative to total rows
- Ordered enumerations (e.g., severity levels, size grades)
- Columns used repeatedly in `groupby` operations

```python
# Convert to Categorical
df["status"] = df["status"].astype("category")

# Ordered Categorical — enables comparisons like > and <
from pandas.api.types import CategoricalDtype
size_type = CategoricalDtype(categories=["S", "M", "L", "XL"], ordered=True)
df["size"] = df["size"].astype(size_type)

# Filter using ordered comparison
df[df["size"] >= "L"]

# Memory comparison
import sys
s_obj = pd.Series(["low", "med", "high"] * 100_000)
s_cat = s_obj.astype("category")
print(s_obj.memory_usage(deep=True))   # ~19 MB
print(s_cat.memory_usage(deep=True))   # ~0.4 MB
```

**When NOT to use Categorical:**

- High-cardinality columns (e.g., UUIDs, free-text) — no memory benefit
- Columns that frequently gain new unique values (requires `cat.add_categories`)
- When exact string comparison performance is paramount (category operations have overhead)

**Working with Categorical columns:**

```python
# Access Categorical-specific methods via .cat accessor
df["status"].cat.categories        # Index of unique values
df["status"].cat.codes             # Integer codes for each row
df["status"].cat.add_categories(["pending"])
df["status"].cat.remove_unused_categories()
df["status"].cat.rename_categories({"low": "LOW"})
```

---

## Numeric Downcasting

Use `pd.to_numeric` with `downcast` to reduce integer and float sizes automatically.

```python
# Downcast integers to smallest unsigned type that fits the data
df["id"] = pd.to_numeric(df["id"], downcast="unsigned")

# Downcast to smallest signed integer
df["delta"] = pd.to_numeric(df["delta"], downcast="signed")

# Downcast floats to float32
df["ratio"] = pd.to_numeric(df["ratio"], downcast="float")

# Convert all numeric columns at once
numeric_cols = df.select_dtypes(include="number").columns
df[numeric_cols] = df[numeric_cols].apply(pd.to_numeric, downcast="integer")
```

Downcasting integer `int64` to `int16` saves 75% memory. Downcasting `float64` to `float32` saves 50%.

**Caution**: `float32` has ~7 decimal digits of precision. Avoid for financial or high-precision scientific computations.

---

## String Data (pandas 3.0)

pandas 3.0 changed the default string dtype from `object` to `str` (backed by Arrow `large_string`). The new default:

- Is more memory-efficient than `object`
- Returns `pd.NA` instead of `np.nan` for missing values
- Supports the full `.str` accessor

```python
# New default in pandas 3.0
s = pd.Series(["hello", "world", None])
print(s.dtype)      # str (Arrow-backed)
print(s.isna())     # True for None position using pd.NA

# Explicit StringDtype variants
pd.StringDtype()                     # Default — uses PyArrow if available, else Python
pd.StringDtype(storage="python")     # Python-native strings
pd.StringDtype(storage="pyarrow")    # PyArrow-backed (most efficient)
pd.StringDtype(na_value=np.nan)      # NumPy NaN semantics (migration compatibility)
```

Avoid `object` dtype for string columns — it stores Python string objects with pointer overhead.

---

## DateTime Types

```python
# Parse dates at read time (avoids re-parsing)
df = pd.read_csv("data.csv", parse_dates=["created_at", "updated_at"])

# Convert existing column
df["date"] = pd.to_datetime(df["date"], format="%Y-%m-%d", utc=True)

# Timezone-aware timestamps
df["ts"] = pd.to_datetime(df["ts"]).dt.tz_localize("UTC").dt.tz_convert("US/Eastern")

# Extract components via .dt accessor
df["year"] = df["date"].dt.year
df["day_of_week"] = df["date"].dt.dayofweek  # 0=Monday
df["is_weekend"] = df["date"].dt.dayofweek >= 5

# Resample time series
daily = df.set_index("date").resample("D")["value"].sum()
```

**Date arithmetic:**

```python
# Timedelta operations
df["duration"] = df["end_date"] - df["start_date"]
df["days"] = df["duration"].dt.days

# Business day offsets
from pandas.tseries.offsets import BDay
df["next_bday"] = df["date"] + BDay(1)
```

---

## Memory Profiling

```python
# Per-column memory usage in bytes
df.memory_usage(deep=True)

# Total memory usage
total_mb = df.memory_usage(deep=True).sum() / 1024**2
print(f"DataFrame uses {total_mb:.2f} MB")

# Identify largest columns
df.memory_usage(deep=True).sort_values(ascending=False).head(10)

# Info with dtype and non-null counts
df.info(memory_usage="deep")
```

**Optimization workflow:**

1. Run `df.memory_usage(deep=True)` to identify large columns.
2. Convert low-cardinality strings to `category`.
3. Downcast numeric columns with `pd.to_numeric(..., downcast=...)`.
4. Replace `object` bool/int columns with nullable types.
5. Re-check with `df.memory_usage(deep=True)`.

---

## Dtype at Read Time

Specifying dtypes when reading data avoids a second pass over the data for conversion.

```python
# CSV with explicit dtypes
df = pd.read_csv(
    "data.csv",
    dtype={
        "user_id": "int32",
        "status": "category",
        "amount": "float32",
        "active": "boolean",
    },
    parse_dates=["created_at"],
)

# Parquet — dtypes are preserved from file schema
df = pd.read_parquet("data.parquet", columns=["user_id", "amount"])

# JSON with dtype specification
df = pd.read_json("data.json", dtype={"id": "int32", "label": "category"})
```

Always prefer column selection at read time (`usecols` for CSV, `columns` for Parquet) over post-read filtering. Reading only needed columns can reduce memory by an order of magnitude on wide datasets.
