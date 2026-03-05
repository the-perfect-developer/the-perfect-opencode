# Advanced Patterns — Python BigQuery SDK

## Table of Contents

1. [Schema Evolution](#schema-evolution)
2. [Partitioned and Clustered Tables](#partitioned-and-clustered-tables)
3. [Querying Partitioned Tables](#querying-partitioned-tables)
4. [Export Jobs](#export-jobs)
5. [Copy Jobs](#copy-jobs)
6. [Retry Configuration](#retry-configuration)
7. [DB-API Interface](#db-api-interface)
8. [External Tables](#external-tables)
9. [Dataset Management](#dataset-management)
10. [Performance Patterns](#performance-patterns)
11. [Testing and Mocking](#testing-and-mocking)

---

## Schema Evolution

### Add a column (NULLABLE or REPEATED only)

```python
table = client.get_table("project.dataset.my_table")
new_fields = table.schema + [
    bigquery.SchemaField("new_column", "STRING", mode="NULLABLE"),
]
table.schema = new_fields
client.update_table(table, ["schema"])
```

Rules:
- Only `NULLABLE` or `REPEATED` columns can be added.
- Columns cannot be removed or renamed directly — use table copy + schema override.
- Column type changes require a full table rewrite.

### Relaxing a column (REQUIRED → NULLABLE)

```python
def relax_field(field: bigquery.SchemaField) -> bigquery.SchemaField:
    return bigquery.SchemaField(
        name=field.name,
        field_type=field.field_type,
        mode="NULLABLE",
        fields=field.fields,
        description=field.description,
    )

new_schema = [relax_field(f) if f.name == "target_col" else f for f in table.schema]
table.schema = new_schema
client.update_table(table, ["schema"])
```

### Schema autodetect (avoid in production)

```python
job_config = bigquery.LoadJobConfig(
    autodetect=True,   # Use only for exploration
)
```

Autodetect can mistype columns (e.g., integer-like strings become INT64). Always specify an explicit schema for production pipelines.

---

## Partitioned and Clustered Tables

### Time-partitioned by ingestion time (pseudo-column `_PARTITIONTIME`)

```python
table.time_partitioning = bigquery.TimePartitioning(
    type_=bigquery.TimePartitioningType.DAY,
    # No `field` → uses ingestion time (_PARTITIONTIME)
    expiration_ms=30 * 24 * 60 * 60 * 1000,  # 30 days retention
)
```

### Time-partitioned by a date/timestamp column

```python
table.time_partitioning = bigquery.TimePartitioning(
    type_=bigquery.TimePartitioningType.DAY,
    field="event_date",   # Must be DATE or TIMESTAMP
)
table.require_partition_filter = True   # Prevent full-table scans
```

### Range partitioning (integer column)

```python
from google.cloud.bigquery.table import PartitionRange, RangePartitioning

table.range_partitioning = RangePartitioning(
    field="shard_id",
    range_=PartitionRange(start=0, end=100, interval=10),
)
```

### Clustering (up to 4 columns, order matters)

```python
table.clustering_fields = ["region", "user_type", "created_at"]
```

Clustering columns should be high-cardinality and frequently filtered. Put the most selective column first.

---

## Querying Partitioned Tables

### Filter on the partition column to prune partitions

```python
sql = """
    SELECT user_id, event
    FROM `project.dataset.events`
    WHERE event_date BETWEEN @start AND @end
"""
config = bigquery.QueryJobConfig(
    query_parameters=[
        bigquery.ScalarQueryParameter("start", "DATE", "2024-01-01"),
        bigquery.ScalarQueryParameter("end", "DATE", "2024-01-31"),
    ]
)
rows = client.query_and_wait(sql, job_config=config)
```

BigQuery prunes partitions only when the filter is on the partition column directly — not inside a function call (e.g., `DATE(event_date)` does **not** prune).

### Writing to a specific partition (decorator syntax)

```python
table_partition = "project.dataset.events$20240115"  # YYYYMMDD suffix
job_config = bigquery.LoadJobConfig(
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    schema=schema,
    source_format=bigquery.SourceFormat.PARQUET,
)
job = client.load_table_from_uri(
    "gs://bucket/events_20240115.parquet",
    table_partition,
    job_config=job_config,
)
job.result()
```

---

## Export Jobs

### Export table to GCS

```python
destination_uri = "gs://my-bucket/export/data-*.csv.gz"
job_config = bigquery.ExtractJobConfig(
    compression=bigquery.Compression.GZIP,
    destination_format=bigquery.DestinationFormat.CSV,
    print_header=True,
    field_delimiter=",",
)
job = client.extract_table(
    "project.dataset.my_table",
    destination_uri,
    job_config=job_config,
)
job.result()
print(f"Exported {job.destination_uri_file_counts} file(s)")
```

Supported destination formats: `CSV`, `NEWLINE_DELIMITED_JSON`, `AVRO`, `PARQUET`.
Use wildcard `*` in URI for sharded output of large tables.

---

## Copy Jobs

### Copy a table

```python
source = "project.dataset.source_table"
dest = "project.dataset.dest_table"
job_config = bigquery.CopyJobConfig(
    create_disposition=bigquery.CreateDisposition.CREATE_IF_NEEDED,
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
)
job = client.copy_table(source, dest, job_config=job_config)
job.result()
```

### Copy across projects (requires IAM on destination)

```python
client.copy_table(
    "source-project.dataset.table",
    "dest-project.dataset.table",
)
```

---

## Retry Configuration

The client uses `google-api-core` retry with exponential backoff by default. Override for tighter or looser control:

```python
from google.api_core.retry import Retry

# Retry idempotent reads up to 5 minutes
custom_retry = Retry(
    initial=1.0,        # seconds
    maximum=60.0,
    multiplier=2.0,
    deadline=300.0,     # total seconds
)

rows = client.query_and_wait(sql, retry=custom_retry)
```

### Retry on jobs

```python
job = client.query(sql)
result = job.result(retry=custom_retry, timeout=300)
```

**Non-retryable errors** (do not retry): `BadRequest` (syntax errors, schema mismatch), `NotFound` (missing table/dataset), `Forbidden` (permission denied).

**Retryable errors**: transient `ServiceUnavailable`, `InternalServerError`, rate-limit `TooManyRequests`.

---

## DB-API Interface

Use `google.cloud.bigquery.dbapi` for SQL-centric code or ORM integration:

```python
from google.cloud.bigquery import dbapi

conn = dbapi.connect(client=client)
cursor = conn.cursor()

cursor.execute(
    "SELECT name FROM `project.dataset.users` WHERE age > %s",
    (18,),
)
for row in cursor.fetchall():
    print(row)

cursor.close()
conn.close()
```

DB-API parameters use `%s` positional placeholders (BigQuery maps them to `@param_N` internally).

`fetchone()`, `fetchmany(size)`, `fetchall()` are all supported.

**Limitations:**
- No transaction support (BigQuery is not transactional for DML in the traditional sense).
- DDL statements (`CREATE TABLE`, `DROP TABLE`) must be run via `client.query()`.

---

## External Tables

Query GCS data without loading it first:

```python
from google.cloud.bigquery.external_config import ExternalConfig, CSVOptions

ext_config = ExternalConfig(source_format=bigquery.SourceFormat.CSV)
ext_config.source_uris = ["gs://my-bucket/data/*.csv"]
ext_config.schema = schema
ext_config.options = CSVOptions(skip_leading_rows=1)

table = bigquery.Table("project.dataset.ext_table")
table.external_data_configuration = ext_config
table = client.create_table(table, exists_ok=True)
```

For Parquet/Avro external tables the schema is inferred from the file metadata — omit `ext_config.schema`.

---

## Dataset Management

### Create a dataset

```python
dataset = bigquery.Dataset("project.my_dataset")
dataset.location = "US"        # Set once; cannot be changed
dataset.default_table_expiration_ms = 90 * 24 * 60 * 60 * 1000  # 90 days
dataset.description = "Production user events"

dataset = client.create_dataset(dataset, exists_ok=True)
```

### List tables in a dataset

```python
tables = client.list_tables("project.my_dataset")
for t in tables:
    print(t.table_id, t.table_type)
```

### Delete a dataset (with all tables)

```python
client.delete_dataset("project.my_dataset", delete_contents=True, not_found_ok=True)
```

---

## Performance Patterns

### Prefer `query_and_wait` for interactive queries

`query_and_wait` uses the faster `jobs.query` REST endpoint (vs the full `jobs.insert` + `jobs.getQueryResults` round-trip). Use `client.query(...).result()` only when needing the `QueryJob` object for monitoring or cancellation.

### Use Arrow for large result sets

```python
arrow_table = rows.to_arrow()
# Convert to pandas only if needed
df = arrow_table.to_pandas()
```

Arrow avoids Python object overhead during deserialization.

### Use Storage Read API for very large exports to Python

```python
# Requires google-cloud-bigquery-storage
df = rows.to_dataframe(create_bqstorage_client=True)
```

This streams data via gRPC instead of REST, yielding 10–100× throughput for large results.

### Avoid `SELECT *`

Select only the columns needed. BigQuery is columnar — unused columns are not scanned but do add to result serialisation cost.

### Cache query results

```python
config = bigquery.QueryJobConfig(use_query_cache=True)  # Default True
```

Identical queries (same SQL + same referenced table data) return cached results at no cost within 24 hours.

### Use `maximum_bytes_billed` to guard against runaway queries

```python
config = bigquery.QueryJobConfig(maximum_bytes_billed=10 * 1024**3)  # 10 GB cap
```

Queries exceeding the limit raise `BadRequest` instead of incurring unexpected cost.

---

## Testing and Mocking

### Unit-test with `unittest.mock`

```python
from unittest.mock import MagicMock, patch

def get_user_count(client: bigquery.Client, project: str) -> int:
    rows = client.query_and_wait(
        f"SELECT COUNT(*) AS cnt FROM `{project}.users.accounts`"
    )
    return next(iter(rows))["cnt"]

def test_get_user_count():
    mock_client = MagicMock(spec=bigquery.Client)
    mock_row = MagicMock()
    mock_row.__getitem__ = lambda self, key: 42 if key == "cnt" else None
    mock_client.query_and_wait.return_value = iter([mock_row])

    assert get_user_count(mock_client, "test-project") == 42
```

### Integration tests against a real project

Use a dedicated test project + dataset and delete it after each test run. Set `GOOGLE_CLOUD_PROJECT` and `GOOGLE_APPLICATION_CREDENTIALS` in CI.

```python
import pytest

@pytest.fixture(scope="session")
def bq_client():
    client = bigquery.Client(project="test-project")
    yield client
    client.close()

@pytest.fixture(scope="session")
def test_dataset(bq_client):
    dataset = bigquery.Dataset("test-project.pytest_tmp")
    dataset.location = "US"
    bq_client.create_dataset(dataset, exists_ok=True)
    yield "test-project.pytest_tmp"
    bq_client.delete_dataset(dataset, delete_contents=True, not_found_ok=True)
```
