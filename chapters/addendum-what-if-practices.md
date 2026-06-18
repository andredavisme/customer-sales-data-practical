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

*Additional "What If" topics will be added here as the textbook develops.*

---

**[← Table of Contents](TOC.md)**
