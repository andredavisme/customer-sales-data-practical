[← Table of Contents](TOC.md)

# Addendum: What If Practices

> *This addendum covers advanced data modeling scenarios that fall outside the scope of the main textbook. The approaches described here are well-established and not particularly complex — they are simply unnecessary for the majority of organizations building on this foundation. If a topic below is relevant to your situation, consider it a starting point for further research rather than a prescription.*

---

## What If I Need Historical Role Attribution?

**Referenced in:** Chapter 3 — Individual Accountability and the User Table

### The Problem

The `user` table in this textbook stores a user's current role. Every record that references a user — requests, estimates, orders — reflects what that user's role is *today*, not what it was when the record was created. For most organizations building operational reporting systems, this is acceptable.

For organizations that require historical accuracy — regulated industries, legal and compliance environments, organizations subject to audit — this may not be sufficient. If Maria was an Admin when she created an order and later became an Executive, the question *"what role did the person who created this order hold at the time?"* requires a different approach.

### The Approaches

**1. Snapshot the role at record creation**
Add a `user_role_at_time` column to any table where historical role attribution matters (e.g., `est_role_at_creation`). Populate it at insert time from the user's current role. This is the simplest approach and requires no changes to the `user` table. The tradeoff is that the snapshot must be maintained manually and is not automatically consistent with the `user` record.

**2. User role history table**
Create a `user_role_history` table that records every role a user has held, with effective start and end dates. To find what role a user held at a given time, join this table on `user_id` and filter by the record's creation timestamp. This is more normalized and more accurate, at the cost of additional join complexity in queries.

**3. Temporal tables (system-versioned)**
Some database systems (including PostgreSQL via extensions, SQL Server natively) support system-versioned temporal tables — tables that automatically track row history with valid-from and valid-to timestamps. The `user` table becomes self-auditing; every change to a user record creates a historical version. Queries can be written to retrieve the state of a user record *as of* any point in time. This is the most robust approach and the most implementation-intensive.

### Which Approach to Choose

| Situation | Recommended Approach |
|-----------|---------------------|
| Operational reporting, no audit requirement | Default `user` table (as described in Chapter 3) |
| Occasional need for historical context | Snapshot the role at record creation |
| Frequent role changes, compliance reporting | User role history table |
| Regulated environment, full audit trail required | Temporal tables |

---

## What If I Need JSON Instead of a Relational Database?

**Referenced in:** Chapter 10 — Layer 3: CRM Integration

### The Problem

The schema in this textbook is designed for a relational database — tables with rows, foreign keys linking them, and SQL as the query language. This is the right foundation for the vast majority of organizations. But some integration targets, APIs, mobile applications, and document stores are built around JSON rather than relational tables. The question is not whether to abandon the relational model — it is whether the same information it captures can be expressed in JSON when a specific use case demands it.

The answer is yes. The relational schema and a JSON representation are not competing designs; they are two views of the same data. The relational schema is the authoritative store. JSON is a derived format, generated from it when needed.

### The Relationship Between Tables and JSON

A relational table is a set of rows, each with the same columns. A JSON object is a set of key-value pairs, some of which may contain nested objects or arrays. The mapping between them is direct:

- A **table row** becomes a **JSON object**
- A **column name** becomes a **JSON key**
- A **foreign key relationship** becomes a **nested object or array** (denormalized into the parent)
- A **one-to-many relationship** (one order, many order lines) becomes a **JSON array**

For example, a single order record with its lines, customer, and delivery status — which in the relational schema requires joining `order`, `order_line`, `customer`, and `delivery` — can be expressed as a single JSON document:

```json
{
  "ord_id": "ORD-00441",
  "ord_date": "2025-09-12",
  "ord_status": "Fulfilled",
  "customer": {
    "cust_id": "CUST-0088",
    "cust_name": "Meridian Supply Co.",
    "cust_segment": "Enterprise"
  },
  "order_lines": [
    {
      "ord_ln_id": "OL-00882",
      "sku_id": "SKU-114",
      "ord_ln_description": "Heavy-duty mounting bracket",
      "ord_ln_qty_ordered": 50,
      "ord_ln_qty_fulfilled": 50,
      "ord_ln_unit_price": 14.75,
      "ord_ln_status": "Fulfilled"
    }
  ],
  "delivery": {
    "del_id": "DEL-00553",
    "del_promised_date": "2025-09-19",
    "del_actual_date": "2025-09-18",
    "del_status": "Delivered"
  }
}
```

This document contains exactly the same information as the relational query that produced it. The difference is shape, not content.

### When to Generate JSON from the Relational Schema

JSON generation is appropriate when:

- An **API or webhook** requires data in JSON format (e.g., sending an order confirmation to a customer portal or third-party logistics system)
- A **mobile or web application** needs a self-contained record without the ability to execute multi-table joins
- A **document store** (MongoDB, Firestore, DynamoDB) is used as a secondary read layer for performance, populated from the relational source of truth
- An **event stream** (Kafka, webhooks) broadcasts record changes to downstream consumers that expect JSON payloads

JSON generation is not appropriate as a replacement for the relational schema in the primary data store. Document stores trade the consistency and query flexibility of a relational model for read performance and schema flexibility. For a system where data integrity, auditability, and cross-entity queries are required — as described throughout this textbook — the relational model remains the right foundation.

### How JSON Is Generated

Most relational databases can produce JSON output natively:

- **PostgreSQL** (used by Supabase in Phase II): `row_to_json()`, `json_agg()`, and `json_build_object()` construct JSON directly from query results. A single query can produce a fully nested JSON document including related records.
- **MySQL / MariaDB**: `JSON_OBJECT()` and `JSON_ARRAYAGG()` provide equivalent functionality.
- **SQL Server**: `FOR JSON PATH` or `FOR JSON AUTO` appended to a SELECT statement returns JSON output.
- **SQLite**: Does not have native JSON aggregation for nested output, but results can be serialized to JSON in the application layer from standard query results.

In a Supabase implementation, the PostgREST API layer automatically exposes the schema as a REST API that returns JSON — no additional generation step is required. A GET request to `/orders?select=ord_id,ord_date,customer(cust_name),order_lines(*)` returns the relational data as a nested JSON document.

### The Key Principle

The relational schema is designed once. JSON representations are derived from it on demand, shaped to the needs of the consumer. Adding a new API consumer or document store does not require redesigning the schema — it requires writing the query or configuration that produces the JSON shape that consumer expects.

This separation — authoritative relational store, derived JSON output — is what keeps the data model stable as integration requirements evolve.

### Which Approach to Choose

| Situation | Recommended Approach |
|-----------|---------------------|
| Primary data store for a sales operation | Relational schema as described in this textbook |
| API or webhook integration requiring JSON | Generate from relational schema using native JSON functions |
| Read-heavy application needing fast document retrieval | Populate a document store from the relational source via ETL or event stream |
| Supabase implementation (Phase II) | PostgREST API returns JSON automatically; no additional generation step needed |
| Replacing the relational model with a document store | Not recommended for systems requiring joins, audit trails, or KPI consistency |

---

*Additional "What If" topics will be added here as the textbook develops.*

---

**[← Table of Contents](TOC.md)**
