# Pandera DataFrameModel Reference

## Table of Contents

1. [Field Specification](#field-specification)
2. [Config Options](#config-options)
3. [Schema Inheritance](#schema-inheritance)
4. [MultiIndex](#multiindex)
5. [Column/Index Aliases](#column-index-aliases)
6. [Optional and Required Columns](#optional-and-required-columns)
7. [Reusable Field Definitions](#reusable-field-definitions)
8. [Parsers (Pre-validation Transforms)](#parsers-pre-validation-transforms)
9. [Validate on Initialization](#validate-on-initialization)
10. [Polars DataFrameModel](#polars-dataframemodel)
11. [Converting to DataFrameSchema](#converting-to-dataframeschema)

---

## Field Specification

`pa.Field(...)` maps to `pa.Column` constraints. Every built-in check is available as a keyword argument.

```python
class Schema(pa.DataFrameModel):
    # Numeric constraints
    user_id: int = pa.Field(gt=0)
    score: float = pa.Field(ge=0.0, le=1.0)
    age: int = pa.Field(in_range={"min_value": 0, "max_value": 150})

    # String constraints
    email: str = pa.Field(str_matches=r"^[^@]+@[^@]+\.[^@]+$")
    slug: str = pa.Field(str_startswith="usr_", str_length={"min_value": 4})

    # Membership
    status: str = pa.Field(isin=["active", "inactive"])

    # Nullable / unique
    notes: str = pa.Field(nullable=True)
    token: str = pa.Field(unique=True)

    # Type coercion
    year: int = pa.Field(gt=2000, coerce=True)

    # Custom check inline
    tags: str = pa.Field(
        pa.Check(lambda s: s.str.count(",") < 10, error="max 10 tags"),
    )
```

### Parametrized Dtypes

For dtypes that require parameters (e.g., `DatetimeTZDtype`, `CategoricalDtype`), use `dtype_kwargs` in `Field` or `Annotated`.

```python
import pandas as pd
from typing import Annotated
import pandera.pandas as pa
from pandera.typing import Series

# Via Field (clearer for complex params)
class TimestampSchema(pa.DataFrameModel):
    created_at: pd.DatetimeTZDtype = pa.Field(
        dtype_kwargs={"unit": "ns", "tz": "UTC"}
    )

# Via Annotated (pass all constructor args in order)
class CatSchema(pa.DataFrameModel):
    priority: Series[Annotated[pd.CategoricalDtype, ["low", "medium", "high"], True]]
```

---

## Config Options

The inner `Config` class controls schema-wide behavior. It must be named exactly `Config`.

```python
class Schema(pa.DataFrameModel):
    col_a: int
    col_b: str

    class Config:
        name = "MySchema"          # appears in error messages
        strict = True              # reject unexpected extra columns
        coerce = True              # cast all columns to declared dtype
        ordered = True             # enforce column ordering
        unique_column_names = True # raise if duplicate column names
        add_missing_columns = True # insert declared columns absent from DataFrame (uses default or None)
```

| Option | Default | Notes |
|---|---|---|
| `strict` | `False` | Set `True` in production to catch schema drift |
| `coerce` | `False` | Prefer per-column coercion to limit side-effects |
| `ordered` | `False` | Useful when column order is semantically significant |
| `name` | class name | Shown in `SchemaError` messages |

---

## Schema Inheritance

Subclass a `DataFrameModel` to add or override fields. Use inheritance to share base constraints across multiple pipeline stages.

```python
class RawEvent(pa.DataFrameModel):
    event_id: str = pa.Field(str_matches=r"^[a-f0-9-]{36}$")  # UUID
    timestamp: int = pa.Field(gt=0)

    class Config:
        coerce = True

class EnrichedEvent(RawEvent):
    user_country: str = pa.Field(str_length={"min_value": 2, "max_value": 2})
    revenue_usd: float = pa.Field(ge=0.0)

    # Override parent field to add a stricter constraint
    timestamp: int = pa.Field(gt=1_000_000_000)

    class Config:
        strict = True
```

Decorators with inheritance:

```python
@pa.check_types
def enrich(df: DataFrame[RawEvent]) -> DataFrame[EnrichedEvent]:
    return df.assign(
        user_country=lookup_country(df["event_id"]),
        revenue_usd=0.0,
    )
```

---

## MultiIndex

Declare multiple `Index` fields; pandera automatically combines them into a `MultiIndex`.

```python
import pandera.pandas as pa
from pandera.typing import Index, Series

class TimeSeriesSchema(pa.DataFrameModel):
    year: Index[int] = pa.Field(gt=2000, coerce=True)
    month: Index[int] = pa.Field(ge=1, le=12, coerce=True)
    value: Series[float] = pa.Field(ge=0)

    class Config:
        multiindex_name = "time"
        multiindex_strict = True
        multiindex_coerce = True
        multiindex_ordered = True
```

---

## Column/Index Aliases

Use `alias` when the DataFrame column name is not a valid Python identifier, or to decouple the attribute name from the column name.

```python
class Schema(pa.DataFrameModel):
    # Column named "first-name" in DataFrame
    first_name: str = pa.Field(alias="first-name")

    # Column matching a regex pattern
    sales_2023: float = pa.Field(alias=r"^sales_\d{4}$", regex=True)

    class Config:
        strict = False  # required when using regex aliases
```

Access the resolved column name via the class attribute:

```python
print(Schema.first_name)  # -> "first-name"
df[[Schema.first_name, Schema.sales_2023]]
```

---

## Optional and Required Columns

All declared fields are required by default. Use `typing.Optional` to allow a column to be absent.

```python
from typing import Optional
import pandera.pandas as pa
from pandera.typing import Series

class Schema(pa.DataFrameModel):
    id: Series[int]                      # required
    name: Series[str]                    # required
    metadata: Optional[Series[str]]      # may be absent from DataFrame
```

---

## Reusable Field Definitions

Use `functools.partial` to create reusable `Field` factories (each call creates a distinct `Field` instance).

```python
from functools import partial
import pandera.pandas as pa
from pandera.pandas import DataFrameModel, Field

# Reusable field factories
PositiveFloat = partial(Field, gt=0.0)
NormalizedScore = partial(Field, ge=0.0, le=1.0)
NonEmptyStr = partial(Field, str_length={"min_value": 1})

class MetricsSchema(DataFrameModel):
    precision: float = NormalizedScore()
    recall: float = NormalizedScore()
    latency_ms: float = PositiveFloat()
    model_name: str = NonEmptyStr()
```

---

## Parsers (Pre-validation Transforms)

Parsers run **before** type checking and checks to standardize/clean data. This keeps transformation logic co-located with the schema.

```python
import pandera.pandas as pa
from pandera.typing import Series

class NormalizedSchema(pa.DataFrameModel):
    email: str
    amount: float

    @pa.parser("email")
    @classmethod
    def lowercase_email(cls, series: pd.Series) -> pd.Series:
        return series.str.lower().str.strip()

    @pa.parser("amount")
    @classmethod
    def strip_currency(cls, series: pd.Series) -> pd.Series:
        return series.replace(r"[$,]", "", regex=True).astype(float)
```

DataFrame-level parser (receives and returns the full DataFrame):

```python
class Schema(pa.DataFrameModel):
    a: int
    b: float

    @pa.dataframe_parser
    @classmethod
    def drop_duplicates(cls, df: pd.DataFrame) -> pd.DataFrame:
        return df.drop_duplicates()
```

---

## Validate on Initialization

Use `DataFrame[Schema](data)` to validate at construction time, producing a typed DataFrame.

```python
from pandera.typing import DataFrame, Series
import pandera.pandas as pa

class OrderSchema(pa.DataFrameModel):
    order_id: str
    quantity: int = pa.Field(gt=0)
    price: float = pa.Field(gt=0.0)

# Validates immediately; raises SchemaError if invalid
orders = DataFrame[OrderSchema]({
    "order_id": ["A001", "A002"],
    "quantity": [2, 5],
    "price": [9.99, 4.50],
})
```

---

## Polars DataFrameModel

The `DataFrameModel` API is largely identical for Polars. Import from `pandera.polars`.

```python
import polars as pl
import pandera.polars as pa
from pandera.typing.polars import DataFrame, Series

class ProductSchema(pa.DataFrameModel):
    product_id: int = pa.Field(gt=0)
    name: str = pa.Field(str_length={"min_value": 1, "max_value": 200})
    price: float = pa.Field(ge=0.0)

    class Config:
        strict = True

@pa.check_types
def process(df: DataFrame[ProductSchema]) -> DataFrame[ProductSchema]:
    return df.filter(pl.col("price") > 0)
```

Notable differences from pandas:
- No `Series` schema support in Polars
- No `Index` validation in Polars
- Groupby checks not supported in Polars
- `drop_invalid_rows=True` is supported in Polars

---

## Converting to DataFrameSchema

Convert a `DataFrameModel` to a `DataFrameSchema` for programmatic inspection or extension.

```python
schema = UserSchema.to_schema()
print(schema)

# Add columns at runtime
extended = schema.add_columns({"audit_ts": pa.Column(int)})

# Rename columns
renamed = schema.rename_columns({"user_id": "id"})

# Select subset of columns
subset = schema.select_columns(["user_id", "email"])
```
