# Pandera Checks and Validation Reference

## Table of Contents

1. [Built-in Check Catalog](#built-in-check-catalog)
2. [Custom Checks](#custom-checks)
3. [Check Groups (Groupby)](#check-groups-groupby)
4. [Wide Checks (DataFrame-level)](#wide-checks-dataframe-level)
5. [Handling Null Values in Checks](#handling-null-values-in-checks)
6. [Warnings vs Errors](#warnings-vs-errors)
7. [Hypothesis Testing](#hypothesis-testing)
8. [Registering Custom Checks as Extensions](#registering-custom-checks-as-extensions)

---

## Built-in Check Catalog

All built-in checks are class methods on `pa.Check`. Prefer these over custom lambdas.

### Comparison

| Check | Description |
|---|---|
| `Check.eq(value)` | Equal to |
| `Check.ne(value)` | Not equal to |
| `Check.gt(value)` | Greater than |
| `Check.ge(value)` | Greater than or equal |
| `Check.lt(value)` | Less than |
| `Check.le(value)` | Less than or equal |
| `Check.in_range(min, max)` | Closed interval `[min, max]` |

### Membership

| Check | Description |
|---|---|
| `Check.isin(iterable)` | Value in set |
| `Check.notin(iterable)` | Value not in set |

### String

| Check | Description |
|---|---|
| `Check.str_matches(pattern)` | Full regex match |
| `Check.str_contains(pattern)` | Contains regex pattern |
| `Check.str_startswith(prefix)` | Starts with string |
| `Check.str_endswith(suffix)` | Ends with string |
| `Check.str_length(min, max)` | Length between min and max |

### Nullability

```python
pa.Column(float, nullable=True)   # allow NaN
pa.Column(str, nullable=False)    # default: no nulls
```

### Uniqueness

```python
pa.Column(int, unique=True)                    # all values unique
pa.DataFrameSchema({...}, unique=["col_a", "col_b"])  # composite uniqueness
```

---

## Custom Checks

### Vectorized (default, preferred)

The check function receives a `pd.Series` and must return a `bool` or a boolean `pd.Series`.

```python
# Vectorized returning bool
pa.Check(lambda s: s.mean() > 10, error="mean must exceed 10")

# Vectorized returning boolean Series (most common)
pa.Check(lambda s: s > 0, error="all values must be positive")
```

### Element-wise

Scalar input, scalar bool output. Use only when per-element logic cannot be vectorised.

```python
pa.Check(
    lambda x: len(x.split(",")) <= 5,
    element_wise=True,
    error="max 5 comma-separated values",
)
```

### Multiple Checks per Column

```python
pa.Column(str, [
    pa.Check.str_length(1, 100),
    pa.Check.str_matches(r"^[A-Za-z0-9_-]+$", error="alphanumeric slug only"),
])
```

### Ignore Null Values in Checks

By default pandera drops nulls before passing data to check functions. To include nulls:

```python
pa.Check(lambda s: s.notna().all(), ignore_na=False)
```

---

## Check Groups (Groupby)

Column checks support grouping by one or more other columns. The check function receives a `dict` mapping group keys to subsets of the validated column.

```python
schema = pa.DataFrameSchema({
    "price": pa.Column(
        float,
        [
            # Single groupby column
            pa.Check(
                lambda g: g["premium"].mean() > g["standard"].mean(),
                groupby="tier",
            ),
            # Multiple groupby columns
            pa.Check(
                lambda g: g[("premium", "US")].median() > 100,
                groupby=["tier", "country"],
            ),
            # Callable groupby (derive columns on the fly)
            pa.Check(
                lambda g: g[True].mean() > 50,
                groupby=lambda df: df.assign(
                    is_premium=df["tier"] == "premium"
                ).groupby("is_premium"),
            ),
        ],
    ),
    "tier": pa.Column(str),
    "country": pa.Column(str),
})
```

---

## Wide Checks (DataFrame-level)

Apply checks across multiple columns at once by passing `checks` to `DataFrameSchema`. The function receives the entire `DataFrame`.

```python
schema = pa.DataFrameSchema(
    columns={
        "start_ts": pa.Column(int),
        "end_ts": pa.Column(int),
        "amount": pa.Column(float, pa.Check.ge(0)),
    },
    checks=[
        pa.Check(
            lambda df: df["end_ts"] > df["start_ts"],
            error="end_ts must be after start_ts",
        ),
        pa.Check(
            lambda df: ~(df["amount"].isna() & df["end_ts"].notna()),
            error="amount cannot be null when end_ts is set",
        ),
    ],
)
```

In `DataFrameModel`, use `@pa.dataframe_check`:

```python
class TransactionSchema(pa.DataFrameModel):
    start_ts: int
    end_ts: int
    amount: float = pa.Field(ge=0)

    @pa.dataframe_check
    @classmethod
    def end_after_start(cls, df: pd.DataFrame) -> pd.Series:
        return df["end_ts"] > df["start_ts"]
```

---

## Handling Null Values

### Column-level nullable flag

```python
# Allow nulls to exist in the column
pa.Column(float, nullable=True)

# DataFrameModel equivalent
class Schema(pa.DataFrameModel):
    revenue: Optional[float] = pa.Field(nullable=True)
```

### Check-level null handling

```python
# Pass nulls through to the check function (not dropped)
pa.Check(lambda s: s.isna().sum() < 10, ignore_na=False)
```

---

## Warnings vs Errors

Set `raise_warning=True` on a `Check` or `Hypothesis` to emit a `SchemaWarning` instead of raising `SchemaError`. Use only for non-critical informational assertions.

```python
import warnings
import pandera.pandas as pa

schema = pa.DataFrameSchema({
    "response_time_ms": pa.Column(
        float,
        pa.Check(
            lambda s: s.mean() < 200,
            error="mean response time exceeds 200ms",
            raise_warning=True,  # monitor, not block
        ),
    )
})

with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter("always")
    validated = schema.validate(df)
    for w in caught:
        print(w.message)
```

**Rule of thumb**: Use `raise_warning=True` for SLA/statistics monitoring. Use the default (raise) for hard data quality requirements.

---

## Hypothesis Testing

Pandera integrates with `scipy.stats` for statistical hypothesis testing via `pa.Hypothesis`.

```python
from scipy.stats import ttest_ind
import pandera.pandas as pa

schema = pa.DataFrameSchema({
    "revenue": pa.Column(
        float,
        pa.Hypothesis(
            test=ttest_ind,
            samples=["control", "treatment"],
            groupby="group",
            relationship=lambda stat, pvalue, alpha=0.05: pvalue < alpha,
            error="revenue not significantly different between groups",
        )
    ),
    "group": pa.Column(str),
})
```

Built-in shortcuts:

```python
# Two-sample t-test
pa.Hypothesis.two_sample_ttest(
    sample1="control",
    sample2="treatment",
    groupby="group",
    alpha=0.05,
    equal_var=True,
)
```

Install extra: `pip install 'pandera[hypotheses]'`

---

## Registering Custom Checks as Extensions

Register reusable checks in the `pa.Check` namespace using `@pa.extensions.register_check_method`.

```python
import pandera.extensions as extensions
import pandera.pandas as pa

@extensions.register_check_method(statistics=["threshold"])
def is_below_threshold(pandas_obj, *, threshold):
    """Check that all values are below threshold."""
    return pandas_obj < threshold

# Use like a built-in
schema = pa.DataFrameSchema({
    "latency_ms": pa.Column(float, pa.Check.is_below_threshold(threshold=500)),
})
```

Requirements:
- Function name becomes the check name on `pa.Check`
- The first positional argument receives the pandas object
- Additional keyword arguments must match `statistics`
- Must return a boolean scalar or boolean Series

For `DataFrameModel` class-based API, registered checks are also available via `pa.Field(is_below_threshold=500)`.
