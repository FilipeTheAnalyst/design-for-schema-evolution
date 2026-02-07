# Part 3: Root Cause Analysis

## Why this keeps happening

The root cause of silent schema failures is **implicit schemas**.

### Implicit vs Explicit schemas

| Aspect | Implicit | Explicit |
|--------|----------|----------|
| Schema definition | Inferred from data at read time | Declared before data is written |
| Breaking change detection | After the fact (if at all) | At write time |
| Column additions | Silent (NULL appears) | Versioned and tracked |
| Column renames | Silent (old column returns NULL) | Blocked or migration required |
| Type changes | Silent coercion or NULL | Validation error |

### The Snowflake VARIANT pattern

Loading JSON into `VARIANT` is convenient:

```sql
CREATE TABLE raw_weather (raw VARIANT, loaded_at TIMESTAMP);
COPY INTO raw_weather FROM @my_stage;
```

But every downstream query becomes an implicit schema:

```sql
SELECT raw:temperature_2m_max::FLOAT  -- implicit contract: this key exists and is numeric
```

There's no enforcement that `temperature_2m_max` exists, is a float, or hasn't been renamed.

### Late detection

By the time the problem is detected:
- Dashboards have been showing wrong data for days/weeks
- Backfills are needed
- Trust in the data is eroded

## The insight

> Schema enforcement should happen **at the storage layer**, not at the query layer.

This is exactly what Apache Iceberg provides.

## What to look at

- [load/snowflake_setup.sql](../load/snowflake_setup.sql) — traditional Snowflake setup
- [load/iceberg_setup.sql](../load/iceberg_setup.sql) — Iceberg alternative with explicit schemas
