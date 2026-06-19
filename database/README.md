# Database

This directory contains all SQL migration files for the **Customer Sales Data Practical** Supabase implementation.

## Schema

All tables are namespaced under the `csdp` PostgreSQL schema to isolate them from other projects sharing the same Supabase instance.

## Migration Files

| File | Description |
|------|-------------|
| `001_csdp_initial_schema.sql` | Creates the `csdp` schema and all 8 tables |
| `002_csdp_seed_data.sql` | Inserts dummy data for 5 customers across the full 8-step journey |

## Table Order (dependency chain)

```
customer → request → estimate → quote → order → delivery → adjustment
                                                          → response
```

## Supabase Project

Hosted in the **Web App Development Course** Supabase project (`us-east-2`).
