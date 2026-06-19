[← Table of Contents](TOC.md)

# Chapter 9: Measuring Performance

**Tier III → IV** | *KPI design, dashboard logic, period-over-period analysis*

---

## The Problem with "How Are We Doing?"

Every business asks it. Most cannot answer it precisely. The schema built across the previous eight chapters contains every transaction in the customer journey — but a row count is not a metric, and a metric is not a KPI.

This chapter is about the gap between having data and having a number that means something. It introduces the structures that turn your transactional schema into a measurement system.

---

## KPI Design Framework

A well-designed KPI must satisfy four requirements:

| Requirement | What It Means |
|---|---|
| **Specific question** | The metric answers exactly one question, stated in plain language |
| **Defined calculation** | Numerator and denominator are written down, not assumed |
| **Time window** | The period is bounded and consistently applied |
| **Baseline** | There is a prior period or target to compare against |

If any one of these is missing, the number is a data point, not a KPI.

### The Denominator Problem

The most common KPI failure is an undefined denominator. "On-time delivery rate" sounds simple until you ask: on-time out of what? All deliveries? Only completed ones? Only those with a promised date? Does a delivery with two shipments count once or twice?

Every denominator must be written down. If two people in the same meeting would calculate the same metric differently, the KPI is not defined.

---

## The Six Baseline Metrics Revisited

The Introduction established six baseline metrics for a customer sales operation. Now, with the full schema in place, each can be defined precisely.

### 1. On-Time Delivery Rate

**Question:** What percentage of deliveries reached the customer by the promised date?

**Numerator:** COUNT of delivery records where `del_actual_date <= del_promised_date` AND `del_status = 'Delivered'` AND `del_type != 'Internal-Transfer'`

**Denominator:** COUNT of delivery records where `del_status = 'Delivered'` AND `del_type != 'Internal-Transfer'` within the period

**Notes:** Internal transfers must be filtered. Partial deliveries (where `del_qty_delivered < del_qty_scheduled`) should be excluded or tracked separately — a partial on-time delivery is not the same as a complete one.

---

### 2. Realized Margin by Segment

**Question:** What is the actual gross margin after all adjustments, by customer segment?

**Numerator:** SUM of `(ord_ln_unit_price × ord_ln_qty_fulfilled) + SUM(adj_price_delta)` — order revenue net of all applied price adjustments

**Denominator:** SUM of `(sku_cost × ord_ln_qty_fulfilled) + SUM(adj_cost_delta)` — order cost net of all applied cost adjustments

**Margin %:** `(Numerator - Denominator) / Numerator`

**Notes:** Only adjustments where `adj_status = 'Applied'` are included. Pending adjustments are an obligation, not a realized figure.

---

### 3. Quote Conversion Rate

**Question:** What percentage of quotes result in an order?

**Numerator:** COUNT of `qte_id` values that have a corresponding `ord_id` (via `ord_qte_id`) within 90 days of `qte_sent_date`

**Denominator:** COUNT of quotes where `qte_sent_date` falls within the period AND `qte_status != 'Draft'`

**Notes:** The 90-day window must be standardized. A quote from November that converts in February should be attributed to the period the quote was sent, not the period the order was placed.

---

### 4. New Customer Rate

**Question:** What percentage of customers placing an order in this period are placing their first-ever order?

**Numerator:** COUNT of `cust_id` values where the earliest `ord_date` across all orders equals an `ord_date` within the current period

**Denominator:** COUNT of distinct `cust_id` values with at least one order in the period

**Notes:** "New customer" must be defined against the entire order history, not just the current year. A customer who ordered two years ago and returns is not new.

---

### 5. Average Order Cycle Time

**Question:** How many days on average does it take from order placement to final delivery?

**Numerator:** SUM of `(MAX(del_actual_date) - ord_date)` for orders where all lines are fulfilled

**Denominator:** COUNT of fully fulfilled orders in the period

**Notes:** Only fully fulfilled orders (all `ord_ln_status = 'Fulfilled'`) should be included. Including partially fulfilled orders understates the true cycle time because the clock hasn't stopped.

---

### 6. Customer Response Rate

**Question:** What percentage of completed deliveries generate a recorded customer response?

**Numerator:** COUNT of `del_id` values that have at least one linked `resp_id`

**Denominator:** COUNT of `del_id` values where `del_status = 'Delivered'` within the period

**Notes:** This metric measures the effectiveness of your feedback collection process as much as customer engagement. A low rate may mean customers are satisfied and silent — or that the follow-up process is broken.

---

## Tier IV Schema Additions

Calculating metrics from the transactional schema on demand is expensive and fragile. Tier IV adds three tables that make reporting fast, consistent, and auditable.

### The `period` Table

Named, bounded reporting periods with an explicit link to the prior period for period-over-period comparison.

| Tier | Column Name | Attribute Name | Notes |
|---|---|---|---|
| IV | per_id | Period ID | PK |
| IV | per_name | Period Name | e.g., '2025-Q3', '2025-10' |
| IV | per_type | Period Type | Monthly / Quarterly / Annual / Custom |
| IV | per_start_date | Start Date | Inclusive |
| IV | per_end_date | End Date | Inclusive |
| IV | per_prior_id | Prior Period ID | FK → per_id; enables period-over-period joins |
| IV | per_is_complete | Is Complete | Boolean; incomplete periods must be flagged in dashboards |

**Why this matters:** Without a period table, period-over-period comparisons require date arithmetic scattered across every query. With it, you join once and the prior period is always in the same row.

---

### The `kpi_snapshot` Table

Pre-calculated metric values per period, per segment, with an audit trail.

| Tier | Column Name | Attribute Name | Notes |
|---|---|---|---|
| IV | ks_id | Snapshot ID | PK |
| IV | ks_kpi_id | KPI Definition ID | FK → kpi_definition |
| IV | ks_per_id | Period ID | FK → period |
| IV | ks_segment | Segment | NULL = all customers; populated for segment-level rows |
| IV | ks_numerator | Numerator | Raw count or sum used in calculation |
| IV | ks_denominator | Denominator | Required; never NULL |
| IV | ks_value | Calculated Value | Numerator / Denominator, or as defined |
| IV | ks_calculated_at | Calculated At | Timestamp of last calculation |
| IV | ks_calculated_by | Calculated By | Process or user that ran the calculation |

**Why this matters:** Dashboards that recalculate on every page load drift when the underlying data is updated mid-month. A snapshot table freezes the number at a defined point and records who calculated it.

---

### The `kpi_definition` Table

Formal documentation of what each metric means — the denominator problem, solved structurally.

| Tier | Column Name | Attribute Name | Notes |
|---|---|---|---|
| IV | kpi_id | KPI ID | PK |
| IV | kpi_name | KPI Name | Short display name |
| IV | kpi_question | Business Question | Plain-language question the KPI answers |
| IV | kpi_numerator_desc | Numerator Description | Written definition |
| IV | kpi_denominator_desc | Denominator Description | Written definition; required |
| IV | kpi_unit | Unit | %, count, days, currency |
| IV | kpi_owner | Owner | Person responsible for the definition |
| IV | kpi_last_reviewed | Last Reviewed | Date the definition was last confirmed |

**Why this matters:** Definitions drift. A column that stores what the number means — and who owns it — makes disagreements auditable rather than political.

---

## Dashboard Logic

Three rules for turning KPI snapshots into a dashboard that supports decisions rather than decorates reports:

1. **Every number needs a visible comparison.** A standalone metric has no meaning. Show the prior period value, the target, or both. The `per_prior_id` column in the period table makes this a single join.

2. **Incomplete periods must be flagged.** A month-to-date number compared to a full prior month will always look worse. Use `per_is_complete` to display a warning or suppress the comparison until the period closes.

3. **Segment before you summarize.** A company-wide on-time delivery rate of 87% may hide one customer tier at 62% and another at 97%. Summary numbers are starting points, not answers.

---

## Period-Over-Period Errors

Three errors that produce misleading period comparisons:

### 1. Comparing Incomplete to Complete Periods

Comparing a month-to-date figure (19 days) to a full prior month (31 days) will almost always show a decline. Always check `per_is_complete` before presenting a change figure.

### 2. Shifting Boundaries

If a customer segment definition changes — for example, "enterprise" is redefined from >$500K to >$750K annual revenue — a period-over-period comparison of enterprise margin is not comparing the same population. Segment definitions must be versioned or the comparison labeled accordingly.

### 3. Ignoring Mix Shifts

Overall on-time delivery rate can improve even when carrier performance degrades, if the mix shifts toward customers or regions with shorter lead times. Segment-level metrics catch this. Summary metrics hide it.

---

## SQL Examples

### 1. Open Order Count with Prior Period Comparison

```sql
SELECT
    p.per_name AS period,
    ks.ks_value AS open_orders,
    ks_prior.ks_value AS prior_open_orders,
    ROUND(((ks.ks_value - ks_prior.ks_value) / NULLIF(ks_prior.ks_value, 0)) * 100, 1) AS pct_change
FROM kpi_snapshot ks
JOIN period p ON ks.ks_per_id = p.per_id
JOIN kpi_definition kd ON ks.ks_kpi_id = kd.kpi_id
LEFT JOIN period p_prior ON p.per_prior_id = p_prior.per_id
LEFT JOIN kpi_snapshot ks_prior
    ON ks_prior.ks_per_id = p_prior.per_id
    AND ks_prior.ks_kpi_id = ks.ks_kpi_id
    AND ks_prior.ks_segment IS NULL
WHERE kd.kpi_name = 'Open Order Count'
    AND ks.ks_segment IS NULL
    AND p.per_type = 'Monthly'
ORDER BY p.per_start_date DESC;
```

---

### 2. On-Time Delivery Rate — Rolling 13 Months via Period Table

```sql
SELECT
    p.per_name,
    COUNT(CASE WHEN d.del_actual_date <= d.del_promised_date THEN 1 END) AS on_time,
    COUNT(*) AS total_delivered,
    ROUND(
        COUNT(CASE WHEN d.del_actual_date <= d.del_promised_date THEN 1 END) * 100.0
        / NULLIF(COUNT(*), 0), 1
    ) AS on_time_pct
FROM delivery d
JOIN period p
    ON d.del_actual_date BETWEEN p.per_start_date AND p.per_end_date
WHERE d.del_status = 'Delivered'
    AND d.del_type != 'Internal-Transfer'
    AND p.per_type = 'Monthly'
    AND p.per_start_date >= DATE('now', '-13 months')
GROUP BY p.per_id, p.per_name, p.per_start_date
ORDER BY p.per_start_date;
```

---

### 3. Realized Margin by Segment and Quarter

```sql
SELECT
    p.per_name AS quarter,
    c.cust_segment,
    ROUND(SUM(
        (ol.ord_ln_unit_price * ol.ord_ln_qty_fulfilled)
        + COALESCE(adj_price.total_price_adj, 0)
    ), 2) AS realized_revenue,
    ROUND(SUM(
        (s.sku_cost * ol.ord_ln_qty_fulfilled)
        + COALESCE(adj_cost.total_cost_adj, 0)
    ), 2) AS realized_cost,
    ROUND(
        (SUM((ol.ord_ln_unit_price * ol.ord_ln_qty_fulfilled) + COALESCE(adj_price.total_price_adj, 0))
        - SUM((s.sku_cost * ol.ord_ln_qty_fulfilled) + COALESCE(adj_cost.total_cost_adj, 0)))
        / NULLIF(SUM((ol.ord_ln_unit_price * ol.ord_ln_qty_fulfilled) + COALESCE(adj_price.total_price_adj, 0)), 0) * 100,
    1) AS margin_pct
FROM order_line ol
JOIN "order" o ON ol.ord_id = o.ord_id
JOIN customer c ON o.ord_cust_id = c.cust_id
JOIN sku s ON ol.sku_id = s.sku_id
JOIN period p ON o.ord_date BETWEEN p.per_start_date AND p.per_end_date
LEFT JOIN (
    SELECT adj_ord_id, SUM(adj_price_delta) AS total_price_adj
    FROM adjustment WHERE adj_status = 'Applied'
    GROUP BY adj_ord_id
) adj_price ON o.ord_id = adj_price.adj_ord_id
LEFT JOIN (
    SELECT adj_ord_id, SUM(adj_cost_delta) AS total_cost_adj
    FROM adjustment WHERE adj_status = 'Applied'
    GROUP BY adj_ord_id
) adj_cost ON o.ord_id = adj_cost.adj_ord_id
WHERE p.per_type = 'Quarterly'
GROUP BY p.per_id, p.per_name, c.cust_segment
ORDER BY p.per_start_date, c.cust_segment;
```

---

### 4. New Customer Rate by Month

```sql
WITH first_orders AS (
    SELECT ord_cust_id, MIN(ord_date) AS first_order_date
    FROM "order"
    GROUP BY ord_cust_id
)
SELECT
    p.per_name,
    COUNT(DISTINCT o.ord_cust_id) AS total_ordering_customers,
    COUNT(DISTINCT CASE
        WHEN fo.first_order_date BETWEEN p.per_start_date AND p.per_end_date
        THEN o.ord_cust_id
    END) AS new_customers,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN fo.first_order_date BETWEEN p.per_start_date AND p.per_end_date
            THEN o.ord_cust_id
        END) * 100.0
        / NULLIF(COUNT(DISTINCT o.ord_cust_id), 0), 1
    ) AS new_customer_pct
FROM "order" o
JOIN period p ON o.ord_date BETWEEN p.per_start_date AND p.per_end_date
JOIN first_orders fo ON o.ord_cust_id = fo.ord_cust_id
WHERE p.per_type = 'Monthly'
    AND p.per_start_date >= DATE('now', '-12 months')
GROUP BY p.per_id, p.per_name
ORDER BY p.per_start_date;
```

---

### 5. Dashboard Seed Query — All Six KPIs from `kpi_snapshot` for Current and Prior Period

```sql
SELECT
    kd.kpi_name,
    kd.kpi_unit,
    p.per_name AS current_period,
    ks.ks_value AS current_value,
    p_prior.per_name AS prior_period,
    ks_prior.ks_value AS prior_value,
    ROUND(((ks.ks_value - ks_prior.ks_value) / NULLIF(ks_prior.ks_value, 0)) * 100, 1) AS pct_change,
    p.per_is_complete AS period_complete
FROM kpi_snapshot ks
JOIN kpi_definition kd ON ks.ks_kpi_id = kd.kpi_id
JOIN period p ON ks.ks_per_id = p.per_id
LEFT JOIN period p_prior ON p.per_prior_id = p_prior.per_id
LEFT JOIN kpi_snapshot ks_prior
    ON ks_prior.ks_per_id = p_prior.per_id
    AND ks_prior.ks_kpi_id = ks.ks_kpi_id
    AND ks_prior.ks_segment IS NULL
WHERE ks.ks_segment IS NULL
    AND p.per_type = 'Monthly'
    AND p.per_end_date = (
        SELECT MAX(per_end_date) FROM period WHERE per_type = 'Monthly'
    )
ORDER BY kd.kpi_name;
```

---

## Reflection

1. Pick any metric your organization reports regularly. Write down its numerator and denominator in one sentence each. Is there ambiguity in either definition? Would two colleagues write the same thing?

2. Does your organization have a definition of "new customer"? Is it written down? Does it distinguish a returning customer from a new one against full history or only recent history?

3. Does your current reporting system flag incomplete periods in period-over-period comparisons, or are month-to-date figures routinely compared to full prior months?

4. Name one metric in your organization that has shifted favorably while the business outcome it was meant to represent stayed flat or got worse. What mix shift or boundary change explains the gap?

5. If the six baseline metrics in this chapter were calculated for your organization tomorrow, which one would produce the most disagreement about the right answer — and what would that disagreement reveal about how definitions are managed?

---

**[← Chapter 8: The Customer's Voice](08-the-customers-voice.md)** | **[Next Chapter → Chapter 10: Building a Sales Intelligence System](10-building-a-sales-intelligence-system.md)**
