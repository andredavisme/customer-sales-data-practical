[← Table of Contents](TOC.md)

# Chapter 10: Building a Sales Intelligence System

**Tier IV** | *Full schema assembly, system design, automation, and the living schema*

---

## What You Have Built

Nine chapters ago, the schema had four columns and one table. It could tell you a customer existed. It could not tell you what they asked for, what you offered them, what you committed to, whether you delivered it on time, what changed along the way, how they felt about it, or whether you made money.

Now it can answer all of those questions — and connect the answers to each other. Before moving to system design, it is worth standing back and reading the schema as a complete object.

---

## The Complete Tier I–IV Schema

Every table introduced across all ten chapters, with the tier in which each was established.

### Core Journey Tables

| Table | First Tier | Purpose |
|---|---|---|
| `customer` | I | Anchor record; every transaction traces back here |
| `request` | I | Initial expression of need |
| `estimate` | I | Internal cost and price assessment |
| `quote` | I | Formal offer to the customer |
| `order` | I | Confirmed commitment |
| `delivery` | I | Record of what was actually delivered and when |
| `adjustment` | I | Any change to a prior record |
| `response` | I | Customer reaction after delivery |

### Supporting and Line-Level Tables

| Table | First Tier | Purpose |
|---|---|---|
| `sku` | II | Product and service catalog with cost |
| `"user"` | II | Internal staff; used for assignments, approvals, contacts |
| `contact` | II | Customer-side contacts linked to the customer record |
| `estimate_line` | II | Line-level detail within an estimate |
| `quote_line` | II | Line-level detail within a quote, linked to estimate lines |
| `order_line` | II/III | Order line detail; fulfillment status updated through Tier III |

### Reporting Tables

| Table | First Tier | Purpose |
|---|---|---|
| `period` | IV | Named, bounded reporting periods with prior-period linkage |
| `kpi_definition` | IV | Formal definitions of each KPI |
| `kpi_snapshot` | IV | Pre-calculated metric values per period, per segment |

---

## What a Sales Intelligence System Is

A sales intelligence system is not a dashboard. A dashboard is a presentation layer — it surfaces numbers. A sales intelligence system is the infrastructure beneath it: the schema that stores transactions, the definitions that govern how those transactions are measured, the processes that keep both current, and the interfaces that put the right information in front of the right people at the right time.

The schema built in this textbook is the foundation. Everything in this chapter is about turning that foundation into a system that operates continuously rather than being queried on demand.

The distinction matters for a specific reason: **a report tells you what happened; a system tells you what is happening and flags what needs attention.** The difference is automation, alerts, and freshness — and all three depend on how the schema is populated and maintained.

---

## System Components

A functioning sales intelligence system has four layers. The schema supports all of them, but each layer requires deliberate design.

### Layer 1: Data Entry and Capture

The schema is only as good as the data written into it. The most common failure mode of a well-designed schema is inconsistent or incomplete population: free-text fields that should be controlled vocabularies, date fields left NULL because no one made them required, status fields that never get updated past the initial value.

Design for capture at the moment of the transaction:

- **Status fields** (`ord_status`, `del_status`, `adj_status`) should be updated by the system when the triggering event occurs, not manually by staff after the fact. A delivery is marked `Delivered` when it is confirmed delivered, not when someone remembers to update the record.
- **Controlled vocabularies** (`adj_type`, `adj_root_cause`, `resp_category`, `resp_sentiment`) should be enforced at the application layer, not validated after the fact. Free-text alternatives are a data quality tax paid on every query.
- **Timestamps** (`ks_calculated_at`, `resp_date`, `adj_approved_date`) should be system-generated, not user-entered. A timestamp a user types is an approximation; a timestamp the system writes is a fact.

### Layer 2: Automation and Triggers

Several fields in the schema exist specifically to support automated processes. These are not optional enhancements — they are the mechanism by which the schema pays for itself.

#### Status Progression Triggers

Each status field in the schema has a defined lifecycle. Automating the transitions removes human delay and creates an accurate audit trail:

| Status Field | Trigger Event | Automated Action |
|---|---|---|
| `ord_status` → `In Progress` | First `order_line` linked to a delivery | Update order status |
| `ord_status` → `Fulfilled` | All `ord_ln_status = 'Fulfilled'` | Update order and set `ord_fulfilled_date` |
| `del_status` → `Delivered` | Carrier confirmation or manual confirmation | Update delivery, calculate `del_days_variance` |
| `adj_status` → `Applied` | Approval recorded (`adj_approved_by` populated) | Update adjustment, trigger credit if `adj_credit_issued = TRUE` |
| `per_is_complete` → `TRUE` | `per_end_date` passes | Update period record; trigger KPI snapshot calculation |

#### Alerts and Queues

The schema has several fields that exist to support action queues rather than just historical records:

- **`qte_valid_until`** — quotes expiring without a linked order are an action item. A daily query against this field generates a salesperson's follow-up list.
- **`adj_status = 'Pending'`** — unapproved adjustments aging beyond a threshold signal an approval bottleneck. The `adj_initiated_date` column enables aging calculation.
- **`resp_followup_required = TRUE` AND `resp_resolved = FALSE`** — the open follow-up queue from Chapter 8. This is not a report; it is a task list that should be surfaced to the responsible owner via `resp_followup_owner`.
- **`del_status` not updated within N days of `del_scheduled_date`** — deliveries that have no confirmation signal either a process gap or an actual delivery failure. Both require investigation.

#### KPI Snapshot Scheduling

The `kpi_snapshot` table introduced in Chapter 9 is populated by a scheduled process, not by ad hoc queries. The schedule determines the freshness of every dashboard built on top of it:

- **Daily:** operational metrics (open orders, open adjustment queue, pending follow-ups)
- **Monthly at period close:** the six baseline KPIs and any segment-level breakdowns; triggered by `per_is_complete` flipping to `TRUE`
- **Quarterly at period close:** margin analysis, cycle time trends, NPS cohort comparisons

The `ks_calculated_at` and `ks_calculated_by` columns record when each snapshot was taken and what process produced it. This makes discrepancies auditable: if a dashboard number doesn't match an analyst's calculation, the snapshot metadata tells you whether the snapshot is stale or the calculation is wrong.

### Layer 3: CRM Integration

The schema in this textbook is database-agnostic by design. The same structure can be implemented in PostgreSQL (the foundation of Supabase, used in Phase II), MySQL, SQL Server, or any relational database. What changes between implementations is not the schema — it is the application layer that reads and writes to it.

A CRM integration connects the schema to a user-facing application that presents the data in context and writes back to it through controlled interfaces. The key principle is that **the schema owns the data; the CRM presents it.** Data written by the CRM should pass through the same constraints and triggers as data written by any other process.

#### What the CRM Reads

- Customer records, contact lists, account hierarchies
- Open requests, quotes pending response, expiring quotes
- Order status and fulfillment progress
- Open adjustment queue by owner
- Response follow-up queue by owner
- KPI snapshots for account-level dashboards

#### What the CRM Writes

- New customer and contact records
- Request creation and updates
- Quote approval (`qte_approved_by`, `qte_approved_date`)
- Adjustment initiation and approval
- Response recording (`resp_type`, `resp_score`, `resp_category`, `resp_sentiment`, `resp_nps`)
- Follow-up resolution (`resp_resolved`, `resp_followup_owner`)

The CRM should never write directly to calculated fields, snapshot tables, or period definitions. Those are owned by the schema's automated processes.

### Layer 4: The Reporting Layer

The reporting layer sits on top of the `kpi_snapshot` and `period` tables, not on top of the transactional schema. This is the architectural decision that separates performant reporting from expensive ad hoc queries.

Transactional queries — "show me this customer's order history" or "what adjustments are pending approval?" — run against the core tables. Analytical queries — "what is our on-time delivery rate trend over 13 months by segment?" — run against the snapshot and period tables.

The division is not absolute. During the current period, before a snapshot exists, the reporting layer must fall back to the transactional schema. The `per_is_complete` flag governs when the snapshot is authoritative and when live calculation is needed.

---

## The Living Schema

No schema survives first contact with production unchanged. New business requirements emerge. Definitions that seemed clear become contested. A field added for one purpose gets repurposed for three others. A table that was designed for one record per order starts accumulating multiple records per order and no one remembers why.

A living schema is one that evolves deliberately rather than drifting. Three practices separate schemas that remain useful over time from schemas that accumulate technical debt until they are replaced:

### Practice 1: Changes Flow Through `kpi_definition`

When a KPI definition changes — a new filter applied, a denominator redefined, a segment boundary shifted — the change should be recorded in `kpi_definition` before it is applied to snapshot calculations. This creates a before/after record:

- `kpi_last_reviewed` is updated
- A note in `kpi_numerator_desc` or `kpi_denominator_desc` records what changed and why
- Historical snapshots are preserved as calculated under the prior definition
- New snapshots are calculated under the new definition

Without this discipline, a trend line that appears to show improvement may actually reflect a redefinition. The `kpi_definition` audit trail makes the distinction visible.

### Practice 2: New Fields Are Additive, Not Overwriting

The tier system used throughout this textbook — adding columns and tables rather than replacing them — is not just a teaching device. It is the correct production approach to schema evolution.

A field that is no longer actively populated is not deleted — it is deprecated with a note and preserved for historical records that contain it. A table that is replaced by a more structured version is not dropped — the old version is retained and the new version is linked to it. This is how you avoid the situation where a three-year trend line is broken because the field it was calculated from was removed during a schema cleanup.

The cost of keeping deprecated fields is low. The cost of losing historical continuity is high.

### Practice 3: Definitions Are Owned, Not Assumed

Every `kpi_definition` record has a `kpi_owner` column. Every period definition is loaded by a named process or person. Every schema change should be attributable to a decision.

This is not bureaucracy — it is the difference between a schema that is auditable and one that is mysterious. When a number changes unexpectedly, the question is always the same: *was this a change in the business, or a change in how we measured it?* A schema with ownership and audit trails can answer that question. One without them cannot.

---

## SQL Examples

### 1. Full Customer Intelligence View — Last 12 Months

A single query assembling the key signals for a customer record: order volume, realized margin, on-time rate, adjustment rate, NPS, and open items.

```sql
WITH customer_orders AS (
    SELECT
        o.ord_cust_id,
        COUNT(DISTINCT o.ord_id) AS total_orders,
        SUM(ol.ord_ln_unit_price * ol.ord_ln_qty_fulfilled) AS gross_revenue,
        SUM(s.sku_cost * ol.ord_ln_qty_fulfilled) AS gross_cost
    FROM "order" o
    JOIN order_line ol ON o.ord_id = ol.ord_id
    JOIN sku s ON ol.sku_id = s.sku_id
    WHERE o.ord_date >= DATE('now', '-12 months')
    GROUP BY o.ord_cust_id
),
adjustment_impact AS (
    SELECT
        o.ord_cust_id,
        COUNT(DISTINCT a.adj_id) AS total_adjustments,
        SUM(COALESCE(a.adj_price_delta, 0)) AS total_price_adj
    FROM adjustment a
    JOIN "order" o ON a.adj_ord_id = o.ord_id
    WHERE a.adj_status = 'Applied'
        AND o.ord_date >= DATE('now', '-12 months')
    GROUP BY o.ord_cust_id
),
delivery_performance AS (
    SELECT
        o.ord_cust_id,
        COUNT(d.del_id) AS total_deliveries,
        COUNT(CASE WHEN d.del_actual_date <= d.del_promised_date THEN 1 END) AS on_time_deliveries
    FROM delivery d
    JOIN "order" o ON d.del_ord_id = o.ord_id
    WHERE d.del_status = 'Delivered'
        AND d.del_type != 'Internal-Transfer'
        AND o.ord_date >= DATE('now', '-12 months')
    GROUP BY o.ord_cust_id
),
nps_summary AS (
    SELECT
        r.cust_id,
        ROUND(AVG(r.resp_nps), 1) AS avg_nps,
        COUNT(r.resp_id) AS response_count
    FROM response r
    WHERE r.resp_nps IS NOT NULL
        AND r.resp_date >= DATE('now', '-12 months')
    GROUP BY r.cust_id
)
SELECT
    c.cust_id,
    c.cust_name,
    c.cust_segment,
    COALESCE(co.total_orders, 0) AS orders_12m,
    ROUND(COALESCE(co.gross_revenue, 0) + COALESCE(ai.total_price_adj, 0), 2) AS realized_revenue,
    ROUND(
        ((COALESCE(co.gross_revenue, 0) + COALESCE(ai.total_price_adj, 0))
        - COALESCE(co.gross_cost, 0))
        / NULLIF(COALESCE(co.gross_revenue, 0) + COALESCE(ai.total_price_adj, 0), 0) * 100,
    1) AS realized_margin_pct,
    ROUND(
        COALESCE(dp.on_time_deliveries, 0) * 100.0
        / NULLIF(dp.total_deliveries, 0), 1
    ) AS on_time_pct,
    COALESCE(ai.total_adjustments, 0) AS adjustments_12m,
    ns.avg_nps,
    ns.response_count
FROM customer c
LEFT JOIN customer_orders co ON c.cust_id = co.ord_cust_id
LEFT JOIN adjustment_impact ai ON c.cust_id = ai.ord_cust_id
LEFT JOIN delivery_performance dp ON c.cust_id = dp.ord_cust_id
LEFT JOIN nps_summary ns ON c.cust_id = ns.cust_id
WHERE co.total_orders > 0
ORDER BY realized_revenue DESC;
```

---

### 2. Open Action Queue — Everything That Needs Attention Today

A single query surfacing all active work items across quotes, adjustments, and response follow-ups.

```sql
SELECT
    'Quote Expiring' AS action_type,
    c.cust_name,
    q.qte_id AS record_id,
    q.qte_valid_until AS due_date,
    (julianday(q.qte_valid_until) - julianday('now')) AS days_remaining,
    u.user_first_name || ' ' || u.user_last_name AS owner
FROM quote q
JOIN customer c ON q.cust_id = c.cust_id
LEFT JOIN "user" u ON q.qte_prepared_by = u.user_id
WHERE q.qte_status NOT IN ('Accepted', 'Cancelled', 'Expired-No-Action', 'Superseded')
    AND q.qte_valid_until <= DATE('now', '+14 days')

UNION ALL

SELECT
    'Adjustment Pending Approval' AS action_type,
    c.cust_name,
    a.adj_id AS record_id,
    DATE(a.adj_initiated_date, '+5 days') AS due_date,
    (julianday('now') - julianday(a.adj_initiated_date)) AS days_remaining,
    u.user_first_name || ' ' || u.user_last_name AS owner
FROM adjustment a
JOIN "order" o ON a.adj_ord_id = o.ord_id
JOIN customer c ON o.ord_cust_id = c.cust_id
LEFT JOIN "user" u ON a.adj_approved_by = u.user_id
WHERE a.adj_status = 'Pending'

UNION ALL

SELECT
    'Response Follow-Up Due' AS action_type,
    c.cust_name,
    r.resp_id AS record_id,
    r.resp_date AS due_date,
    (julianday('now') - julianday(r.resp_date)) AS days_remaining,
    u.user_first_name || ' ' || u.user_last_name AS owner
FROM response r
JOIN customer c ON r.cust_id = c.cust_id
LEFT JOIN "user" u ON r.resp_followup_owner = u.user_id
WHERE r.resp_followup_required = TRUE
    AND r.resp_resolved = FALSE

ORDER BY days_remaining DESC;
```

---

### 3. Journey Completeness Audit — Orphaned or Stalled Records

Identifies records that have stalled or broken the journey chain: requests with no estimate, estimates with no quote, orders with no delivery activity.

```sql
SELECT 'Request without Estimate' AS gap_type, r.req_id AS record_id, r.cust_id,
    r.req_date AS record_date
FROM request r
LEFT JOIN estimate e ON r.req_id = e.req_id
WHERE e.est_id IS NULL
    AND r.req_date < DATE('now', '-30 days')

UNION ALL

SELECT 'Estimate without Quote', e.est_id, e.cust_id, e.est_date
FROM estimate e
LEFT JOIN quote q ON e.est_id = q.est_id
WHERE q.qte_id IS NULL
    AND e.est_date < DATE('now', '-30 days')

UNION ALL

SELECT 'Quote Sent without Response', q.qte_id, q.cust_id, q.qte_sent_date
FROM quote q
LEFT JOIN "order" o ON q.qte_id = o.qte_id
WHERE q.qte_sent_date IS NOT NULL
    AND o.ord_id IS NULL
    AND q.qte_status NOT IN ('Cancelled', 'Expired-No-Action', 'Superseded')
    AND q.qte_sent_date < DATE('now', '-14 days')

UNION ALL

SELECT 'Order without Delivery Activity', o.ord_id, o.ord_cust_id, o.ord_date
FROM "order" o
LEFT JOIN delivery d ON o.ord_id = d.del_ord_id
WHERE d.del_id IS NULL
    AND o.ord_status NOT IN ('Cancelled', 'On Hold')
    AND o.ord_date < DATE('now', '-7 days')

ORDER BY gap_type, record_date;
```

---

### 4. Schema Change Impact Assessment

Before changing a KPI definition, identify which snapshot records were calculated under the prior definition and which periods would need recalculation.

```sql
SELECT
    kd.kpi_name,
    kd.kpi_last_reviewed,
    COUNT(ks.ks_id) AS snapshot_count,
    MIN(p.per_start_date) AS earliest_period,
    MAX(p.per_end_date) AS latest_period,
    SUM(CASE WHEN p.per_is_complete = TRUE THEN 1 ELSE 0 END) AS complete_periods,
    SUM(CASE WHEN p.per_is_complete = FALSE THEN 1 ELSE 0 END) AS incomplete_periods
FROM kpi_definition kd
JOIN kpi_snapshot ks ON kd.kpi_id = ks.ks_kpi_id
JOIN period p ON ks.ks_per_id = p.per_id
WHERE ks.ks_segment IS NULL
GROUP BY kd.kpi_id, kd.kpi_name, kd.kpi_last_reviewed
ORDER BY kd.kpi_name;
```

---

### 5. System Health Check — Data Freshness and Population Quality

A diagnostic query to surface population gaps: fields that should never be NULL but are, status fields that have not moved in unexpectedly long periods, and snapshot freshness.

```sql
SELECT 'Orders with NULL status' AS check_name,
    COUNT(*) AS issue_count
FROM "order"
WHERE ord_status IS NULL

UNION ALL

SELECT 'Deliveries with NULL promised date',
    COUNT(*)
FROM delivery
WHERE del_promised_date IS NULL
    AND del_status != 'Cancelled'

UNION ALL

SELECT 'Adjustments with no root cause (Applied)',
    COUNT(*)
FROM adjustment
WHERE adj_root_cause IS NULL
    AND adj_status = 'Applied'

UNION ALL

SELECT 'Responses with score but no scale',
    COUNT(*)
FROM response
WHERE resp_score IS NOT NULL
    AND resp_score_scale IS NULL

UNION ALL

SELECT 'KPI snapshots older than 48 hours (complete periods)',
    COUNT(*)
FROM kpi_snapshot ks
JOIN period p ON ks.ks_per_id = p.per_id
WHERE p.per_is_complete = TRUE
    AND ks.ks_calculated_at < DATETIME('now', '-48 hours')

ORDER BY issue_count DESC;
```

---

## Reflection

1. Of the four system layers — data capture, automation, CRM integration, and reporting — which one is most likely to be the weakest in your organization today? What would break if you audited it honestly?

2. Walk through the open action queue query in this chapter. Does your organization currently have a single view across expiring quotes, pending adjustments, and open follow-ups? Or are those three lists maintained separately, by different teams, in different tools?

3. The journey completeness audit query surfaces requests with no estimate, estimates with no quote, and orders with no delivery. How many records in your current system would that query return? What does the answer tell you about where the customer journey breaks down most often?

4. The living schema practice of preserving deprecated fields rather than deleting them has a cost: a schema that accumulates columns over time. Where does your organization draw that line, and how is the decision made? Is it made deliberately, or does it happen by accident during system migrations?

5. If the system health check query ran against your database tomorrow and returned a count for each check — how confident are you in what those numbers would be? The answer to that question is a measure of how well you know your own data.

---

**[← Chapter 9: Measuring Performance](09-measuring-performance.md)**

---

*You have reached the end of the textbook. The complete Tier I–IV schema is now assembled. The database implementation supporting this model is built in Phase II using Supabase. The CRM application putting this schema to work with live data is available in Phase III.*
