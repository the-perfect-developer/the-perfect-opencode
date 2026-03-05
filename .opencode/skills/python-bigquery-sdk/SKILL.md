---
name: python-bigquery-sdk
description: This skill should be used when the user asks to "query BigQuery with Python", "use the google-cloud-bigquery SDK", "load data into BigQuery", "define a BigQuery schema", or needs guidance on best practices for the Python BigQuery client library.
---

# Python BigQuery SDK

Provides workflows and best practices for the `google-cloud-bigquery` Python client library (v3.x) covering client setup, querying, schema definition, data loading, and result consumption.

## Installation

```bash
pip install google-cloud-bigquery
# Optional extras for Arrow/pandas integration
pip install "google-cloud-bigquery[pandas,pyarrow]"
```

## Client Initialisation

Instantiate `Client` once per process and reuse it. The client is thread-safe.

```python
from google.cloud import bigquery

# Picks up credentials from GOOGLE_APPLICATION_CREDENTIALS or ADC
client = bigquery.Client(project="my-project")

# Explicit project + credentials
from google.oauth2 import service_account
credentials = service_account.Credentials.from_service_account_file("key.json")
client = bigquery.Client(project="my-project", credentials=credentials)
```

**Key rules:**
- Never create a `Client` inside a per-request or per-row function.
- Always set `project` explicitly in production; avoid relying on environment inference.
- Close the client with `client.close()` or use it as a context manager when appropriate.

## Running Queries

### Simple query (blocking)

```python
query = "SELECT name, age FROM `my-project.my_dataset.users` WHERE age > 18"
rows = client.query_and_wait(query)  # Returns RowIterator directly (v3+)
for row in rows:
    print(row["name"], row.age)
```

`query_and_wait` is preferred over the legacy `client.query(...).result()` pattern for short interactive queries.

### Parameterised queries (mandatory for untrusted input)

Always use query parameters — never string-format user input into SQL.

```python
from google.cloud.bigquery import ScalarQueryParameter, QueryJobConfig

config = QueryJobConfig(
    query_parameters=[
        ScalarQueryParameter("min_age", "INT64", 18),
        ScalarQueryParameter("country", "STRING", "US"),
    ]
)
sql = """
    SELECT name FROM `project.dataset.users`
    WHERE age > @min_age AND country = @country
"""
rows = client.query_and_wait(sql, job_config=config)
```

Parameter types map to BigQuery SQL types: `"STRING"`, `"INT64"`, `"FLOAT64"`, `"BOOL"`, `"TIMESTAMP"`, `"DATE"`, `"BYTES"`.

Use `ArrayQueryParameter` for list inputs:

```python
from google.cloud.bigquery import ArrayQueryParameter

config = QueryJobConfig(
    query_parameters=[
        ArrayQueryParameter("ids", "INT64", [1, 2, 3]),
    ]
)
```

### Asynchronous / long-running queries

```python
job = client.query(sql, job_config=config)   # Returns QueryJob immediately
# ... do other work ...
rows = job.result(timeout=300)               # Block until complete or timeout
print(f"Bytes processed: {job.total_bytes_processed}")
```

Check `job.state` (`"RUNNING"`, `"DONE"`) and `job.error_result` before consuming results.

### Dry-run (cost estimation)

```python
dry_config = QueryJobConfig(dry_run=True, use_query_cache=False)
job = client.query(sql, job_config=dry_config)
print(f"Estimated bytes: {job.total_bytes_processed}")
```

## Consuming Results

### Iterate rows

```python
for row in rows:
    value = row["column_name"]   # by name
    value = row[0]               # by position
    value = row.column_name      # attribute access
```

### Convert to pandas DataFrame

```python
df = rows.to_dataframe()                  # requires pandas + pyarrow
df = rows.to_dataframe(dtypes={"age": "Int64"})
```

### Convert to Arrow Table

```python
table = rows.to_arrow()
```

`to_arrow()` is faster than `to_dataframe()` for large result sets; convert after if needed.

### Page size control

```python
rows = client.query_and_wait(sql, max_results=1000)   # cap result rows
```

## Schema Definition

Define schemas explicitly — never rely on autodetect in production.

```python
schema = [
    bigquery.SchemaField("user_id", "INT64", mode="REQUIRED"),
    bigquery.SchemaField("email", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("created_at", "TIMESTAMP", mode="NULLABLE"),
    bigquery.SchemaField(
        "address",
        "RECORD",
        mode="NULLABLE",
        fields=[
            bigquery.SchemaField("city", "STRING"),
            bigquery.SchemaField("postcode", "STRING"),
        ],
    ),
]
```

| Mode | Meaning |
|---|---|
| `REQUIRED` | NOT NULL; value must be present |
| `NULLABLE` | Default; value may be NULL |
| `REPEATED` | Array of the given type |

Standard SQL types: `STRING`, `BYTES`, `INTEGER`/`INT64`, `FLOAT`/`FLOAT64`, `NUMERIC`, `BIGNUMERIC`, `BOOLEAN`/`BOOL`, `TIMESTAMP`, `DATE`, `TIME`, `DATETIME`, `GEOGRAPHY`, `JSON`, `RECORD`/`STRUCT`.

## Creating Tables

```python
dataset_ref = client.dataset("my_dataset")
table_ref = dataset_ref.table("my_table")
table = bigquery.Table(table_ref, schema=schema)

# Time partitioning
table.time_partitioning = bigquery.TimePartitioning(
    type_=bigquery.TimePartitioningType.DAY,
    field="created_at",
    expiration_ms=7 * 24 * 60 * 60 * 1000,  # 7 days
)

# Clustering
table.clustering_fields = ["country", "user_id"]

table = client.create_table(table, exists_ok=True)
```

## Loading Data

### From a local file

```python
job_config = bigquery.LoadJobConfig(
    schema=schema,
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
)
with open("data.ndjson", "rb") as f:
    job = client.load_table_from_file(f, table_ref, job_config=job_config)
job.result()  # Wait for completion
```

### From Google Cloud Storage

```python
uri = "gs://my-bucket/data/*.parquet"
job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.PARQUET,
    write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
)
job = client.load_table_from_uri(uri, table_ref, job_config=job_config)
job.result()
```

### From a pandas DataFrame

```python
job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
job.result()
```

### Write dispositions

| Value | Behaviour |
|---|---|
| `WRITE_TRUNCATE` | Replace all existing rows |
| `WRITE_APPEND` | Add rows to existing data |
| `WRITE_EMPTY` | Fail if table already contains data |

## Inserting Rows (Streaming)

Use the Storage Write API via `google-cloud-bigquery-storage` for high-throughput streaming. For simple cases:

```python
errors = client.insert_rows_json(table_ref, [
    {"user_id": 1, "email": "a@example.com"},
    {"user_id": 2, "email": "b@example.com"},
])
if errors:
    raise RuntimeError(f"Streaming insert errors: {errors}")
```

**Caution:** `insert_rows_json` does not guarantee exactly-once delivery and has per-row cost. Prefer batch load jobs for bulk ingestion.

## Error Handling

```python
from google.cloud.exceptions import GoogleCloudError
from google.api_core.exceptions import BadRequest, NotFound

try:
    rows = client.query_and_wait(sql)
except BadRequest as exc:
    # SQL syntax / schema errors
    print(f"Query error: {exc.message}")
except NotFound as exc:
    print(f"Table or dataset not found: {exc}")
except GoogleCloudError as exc:
    print(f"API error: {exc}")
```

Always inspect `job.errors` after async jobs:

```python
job = client.query(sql)
job.result()
if job.errors:
    for err in job.errors:
        print(err["message"], err.get("reason"))
```

## Quick Reference: Key Classes

| Class | Module | Purpose |
|---|---|---|
| `Client` | `google.cloud.bigquery.client` | Entry point for all API calls |
| `QueryJobConfig` | `google.cloud.bigquery.job` | Query execution options |
| `LoadJobConfig` | `google.cloud.bigquery.job` | Load job options |
| `SchemaField` | `google.cloud.bigquery.schema` | Column definition |
| `Table` | `google.cloud.bigquery.table` | Table resource |
| `Dataset` | `google.cloud.bigquery.dataset` | Dataset resource |
| `TimePartitioning` | `google.cloud.bigquery.table` | Partitioning config |
| `ScalarQueryParameter` | `google.cloud.bigquery.query` | Single-value param |
| `ArrayQueryParameter` | `google.cloud.bigquery.query` | Array param |
| `StructQueryParameter` | `google.cloud.bigquery.query` | Struct param |
| `WriteDisposition` | `google.cloud.bigquery.enums` | Overwrite vs append |
| `SourceFormat` | `google.cloud.bigquery.enums` | Input file format |

## Additional Resources

### Reference Files

For deeper coverage consult:

- **`references/advanced-patterns.md`** — Schema evolution, partitioned table queries, export jobs, retry configuration, DB-API usage, and performance patterns

### Official Docs

- API reference: https://docs.cloud.google.com/python/docs/reference/bigquery/latest/summary_overview
- Client class: https://docs.cloud.google.com/python/docs/reference/bigquery/latest/google.cloud.bigquery.client.Client
