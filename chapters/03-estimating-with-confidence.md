[← Table of Contents](TOC.md)

# Chapter 3: Estimating with Confidence

**Tier II** | *Cost vs. price modeling, margin tracking, SKU introduction, user accountability*

---

## Business Context

An estimate is your organization's internal answer to a customer's request. It is the moment where ambition meets reality — where you translate *"can you do this?"* into *"here is what it will take, here is what it will cost us, and here is what we will charge."*

Tier I captures the skeleton of that answer: an estimated delivery date, a cost, a price, and a field for alerts. That is enough to know an estimate existed and roughly what it contained. It is not enough to understand *how* the estimate was built, *what it is made of*, or *how confidently it was made*.

Consider a job that comes in over budget at delivery. You pull up the estimate and find a single cost figure: $14,200. Was that one line item or forty? Was it a product cost, a labor cost, or both? Did anyone flag a risk before the job started? The data cannot tell you. The estimate was recorded as an outcome, not as a process — and when something goes wrong, there is nothing to audit.

Tier II changes that. It introduces the building blocks of the estimate: the individual products and services being priced, the margin being targeted, a structured approach to flagging risk before a quote is ever sent, and — for the first time in this schema — the person responsible for the work.

---

## The Data Gap

With the Tier I `estimate` table, here are the questions you cannot answer:

- What specific products or services are included in this estimate?
- What is the margin on this estimate, and is it within acceptable bounds?
- How was the estimated cost derived — from a catalog price, a custom calculation, or a guess?
- Were there any risks or constraints flagged during the estimation process, and what were they?
- How does this estimate compare to similar estimates for similar requests?
- Who prepared this estimate, and when?

The Tier I `est_alerts` field acknowledges that alerts exist, but stores them as free text. A flag buried in a text field is not actionable data — it is a note. Tier II makes alerts structured, trackable, and queryable.

---

## Cost vs. Price: The Margin Gap

The Tier I estimate table already carries both `est_cost` and `est_price`. This is the right structure. But the presence of both fields creates an obligation: you must use them correctly and consistently, or the margin data they produce is worthless.

**Cost** is what it takes for your organization to fulfill the request. It includes materials, labor, overhead, logistics — everything you spend to deliver. Cost is internal.

**Price** is what the customer pays. It is the cost plus your margin, adjusted for market conditions, customer tier, competitive pressure, and strategy. Price is external.

The gap between them is **margin** — and margin is one of the most important numbers in any sales operation. At the estimate stage, margin is still a target. It has not been committed to a quote or tested against a customer response. That makes the estimate the earliest and most valuable place to catch deals that are structurally unprofitable before they ever leave the building.

```
Estimated Margin % = (est_price - est_cost) / est_price * 100
```

This calculation requires no new fields — it is derived from what Tier I already provides. What Tier II adds is the context to make that margin figure meaningful: what is it made of, and is it reasonable given what is being estimated?

---

## Introducing SKUs

A SKU — Stock Keeping Unit — is the atomic unit of what you sell. Every product, every service offering, every billable item your organization provides can be assigned a SKU. When estimates reference SKUs rather than free-text descriptions, the entire data model gains precision.

Without SKUs, an estimate for "installation services" is a description. With a SKU, it is a reference to a defined service item with a standard cost, a standard price, a lead time, and a history of how it has been estimated and delivered in the past.

SKUs belong in their own table — a catalog of everything you offer. The estimate does not need to copy all of that information; it only needs to reference the SKU by ID. This is the principle of normalization in practice: store information once, reference it everywhere.

The relationship between estimates and SKUs introduces a new concept: the **estimate line**. A single estimate can cover multiple products or services. Each line represents one SKU, one quantity, one cost, and one price. The total estimate is the sum of its lines.

This means we need two new structures in Tier II:
- A `sku` table — the catalog of what you offer
- An `estimate_line` table — the line items that make up each estimate

---

## Estimate Alerts: From Text to Structure

The Tier I `est_alerts` field is a free-text field. It exists to capture risk — supply constraints, capacity issues, lead time uncertainty, margin concerns — but as a text blob it cannot be filtered, counted, or acted upon systematically.

Tier II replaces this approach with a structured `est_alert_type` field and an `est_alert_notes` field. The type is a controlled vocabulary — a fixed set of values your organization defines (e.g., *Supply Risk*, *Margin Below Threshold*, *Lead Time Uncertainty*, *Requires Approval*, *Capacity Constraint*). The notes field preserves the free-text detail for human review.

This separation — type for filtering and routing, notes for context — is a pattern that will appear throughout this textbook. Structured fields answer questions. Free-text fields provide explanations. Both are needed; neither can do the other's job.

---

## Individual Accountability and the User Table

Estimates are prepared by people. People make different assumptions, apply different judgment, and carry different levels of accuracy. Knowing *who* built an estimate — and holding that answer in a structured, consistent way — is the foundation of process accountability.

The naive approach is to store the preparer's name as a text field: `est_prepared_by = 'Maria Santos'`. This works until Maria goes by "M. Santos" in one record, "msantos" in another, and "Maria S." in a third. Text fields applied to people decay into inconsistency. They cannot be reliably grouped, filtered, or joined.

The right approach is to store a reference to a person record: `est_prepared_by = user_id`. That user record lives in a dedicated `user` table — a single source of truth for every person in your organization who interacts with the data.

### Why a Dedicated User Table?

The `user` table serves three purposes that extend well beyond the estimate:

1. **Consolidation of roles** — A user's role — estimator, sales rep, operations manager, approver — is stored once and referenced wherever that person appears in the schema. When a user's role changes, one record updates and the change is reflected everywhere.

2. **Consistent ownership across tables** — The `req_owner` field introduced in Chapter 2, the `est_prepared_by` field in this chapter, and every future ownership or assignment field in the schema will all reference the same `user` table. This means you can ask cross-table questions: *which users have the most open requests AND the most pending estimates?*

3. **Future security access** — In Phase II, when this schema is implemented in a live database, the `user` table becomes the anchor for row-level security, permission scoping, and audit logging. The groundwork laid here — a clean, normalized user record — makes that implementation straightforward rather than retrofitted.

Introducing the `user` table in Chapter 3 is intentional. The estimate is the first record in the chain where internal accountability is both meaningful and analytically valuable. It is also the right moment to establish the pattern before it is needed in every subsequent chapter.

---

## Tier II Schema Updates

### New Table: `user`

The internal user directory. Every person in your organization who creates, owns, approves, or acts on a record references this table.

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `user_id` | User ID | Primary key |
| II | `user_first_name` | First Name | |
| II | `user_last_name` | Last Name | |
| II | `user_email` | Email Address | Unique — used as login identifier |
| II | `user_role` | Role | Functional role in the organization: e.g., Estimator, Sales Rep, Operations Manager, Approver |
| II | `user_department` | Department | Organizational unit: e.g., Sales, Operations, Finance |
| II | `user_active` | Active Flag | Boolean — false if the user has left the organization |

### New Table: `sku`

The catalog of products and services your organization offers.

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `sku_id` | SKU ID | Primary key |
| II | `sku_code` | SKU Code | Human-readable identifier (e.g., PROD-1042, SVC-INSTALL-A) |
| II | `sku_name` | SKU Name | Descriptive name of the product or service |
| II | `sku_category` | SKU Category | Product or Service; mirrors `req_category` from Chapter 2 |
| II | `sku_unit` | Unit of Measure | e.g., Each, Hour, Day, Pound, Linear Foot |
| II | `sku_std_cost` | Standard Cost | Default internal cost; used as the baseline for estimation |
| II | `sku_std_price` | Standard Price | Default list price; used as the baseline for quoting |
| II | `sku_active` | Active Flag | Boolean — false if this SKU is discontinued or unavailable |

### New Table: `estimate_line`

The individual line items that make up an estimate. One row per SKU per estimate.

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `est_line_id` | Estimate Line ID | Primary key |
| II | `est_id` | Estimate ID | Foreign key → `estimate` |
| II | `sku_id` | SKU ID | Foreign key → `sku` |
| II | `est_line_qty` | Quantity | Number of units of this SKU in the estimate |
| II | `est_line_cost` | Line Cost | Actual cost for this line (may differ from `sku_std_cost`) |
| II | `est_line_price` | Line Price | Actual price for this line (may differ from `sku_std_price`) |
| II | `est_line_notes` | Line Notes | Optional clarification or override rationale for this line |

### Updated: `estimate` Table

New attributes added in Tier II:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `est_date` | Estimate Date | Timestamp when the estimate was prepared; system-generated |
| II | `est_prepared_by` | Prepared By | Foreign key → `user`; the user who built the estimate |
| II | `est_alert_type` | Alert Type | Controlled vocabulary: e.g., Supply Risk, Margin Below Threshold, Lead Time Uncertainty, Requires Approval |
| II | `est_alert_notes` | Alert Notes | Free-text detail supporting the alert type |

*Note: `est_alerts` from Tier I is superseded by `est_alert_type` and `est_alert_notes` in Tier II. `est_prepared_by` references `user.user_id` — not a text name.*

### Updated: `request` Table (retroactive)

With the `user` table now established, the `req_owner` field introduced in Chapter 2 is formalized as a foreign key:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `req_owner` | Request Owner | Foreign key → `user`; previously noted as a text field in Chapter 2 |

---

## Analytical Application

### What is the estimated margin on each open estimate?

```sql
SELECT
  e.est_id,
  c.cust_name,
  e.est_cost,
  e.est_price,
  ROUND((e.est_price - e.est_cost) / NULLIF(e.est_price, 0) * 100, 1) AS margin_pct
FROM estimate e
JOIN customer c ON e.cust_id = c.cust_id
JOIN request r ON e.req_id = r.req_id
WHERE r.req_status NOT IN ('Closed - Fulfilled', 'Closed - Declined')
ORDER BY margin_pct ASC;
```

Sorting by margin ascending surfaces the most at-risk deals first — the ones most likely to be unprofitable if they convert.

### Which estimates have active alerts requiring approval?

```sql
SELECT
  e.est_id,
  c.cust_name,
  u.user_first_name || ' ' || u.user_last_name AS prepared_by,
  e.est_alert_type,
  e.est_alert_notes,
  e.est_date
FROM estimate e
JOIN customer c ON e.cust_id = c.cust_id
JOIN "user" u ON e.est_prepared_by = u.user_id
WHERE e.est_alert_type = 'Requires Approval'
ORDER BY e.est_date ASC;
```

### How does estimated cost compare to standard cost, by SKU?

```sql
SELECT
  s.sku_code,
  s.sku_name,
  ROUND(AVG(el.est_line_cost), 2)                         AS avg_estimated_cost,
  s.sku_std_cost                                          AS standard_cost,
  ROUND(AVG(el.est_line_cost) - s.sku_std_cost, 2)       AS avg_cost_variance
FROM estimate_line el
JOIN sku s ON el.sku_id = s.sku_id
GROUP BY s.sku_id, s.sku_code, s.sku_name, s.sku_std_cost
ORDER BY avg_cost_variance DESC;
```

This query identifies SKUs that are consistently estimated above or below standard cost. A persistent positive variance may indicate the standard cost is outdated. A persistent negative variance may indicate that estimators are cutting corners or applying unapproved discounts.

### Who are the most accurate estimators?

```sql
SELECT
  u.user_first_name || ' ' || u.user_last_name           AS estimator,
  COUNT(e.est_id)                                         AS estimates_prepared,
  ROUND(AVG(ABS(e.est_cost - o.ord_cost)), 2)            AS avg_cost_variance,
  ROUND(AVG(ABS(e.est_price - o.ord_price)), 2)          AS avg_price_variance
FROM estimate e
JOIN "user" u ON e.est_prepared_by = u.user_id
JOIN "order" o ON e.est_id = o.est_id
GROUP BY u.user_id, estimator
ORDER BY avg_cost_variance ASC;
```

This query compares what was estimated to what was eventually ordered, by preparer. Lower variance means more accurate estimation. Use this to coach and improve, not to punish.

### Which users have both open requests and pending estimates?

```sql
SELECT
  u.user_id,
  u.user_first_name || ' ' || u.user_last_name           AS user_name,
  COUNT(DISTINCT r.req_id)                                AS open_requests,
  COUNT(DISTINCT e.est_id)                                AS pending_estimates
FROM "user" u
LEFT JOIN request r
  ON r.req_owner = u.user_id AND r.req_status = 'Open'
LEFT JOIN estimate e
  ON e.est_prepared_by = u.user_id
  AND e.est_alert_type IS NOT NULL
GROUP BY u.user_id, user_name
HAVING COUNT(DISTINCT r.req_id) > 0
   AND COUNT(DISTINCT e.est_id) > 0
ORDER BY open_requests DESC;
```

This cross-table query is only possible because both `req_owner` and `est_prepared_by` reference the same `user` table. It demonstrates the payoff of the architectural decision made in this chapter.

---

## Reflection

1. When your organization prepares an estimate today, is it a single number or a collection of line items? If it is a single number, what information is lost when that estimate is reviewed months later?

2. Think about your most common products or services. Could you assign each one a SKU with a standard cost and a standard price? What would prevent that standardization, and what would it take to get there?

3. How are people currently identified in your data systems? Are names stored as text in multiple places? What inconsistencies has that created, and what would a single user record resolve?

4. If you could query every open request and every pending estimate by the person responsible for each — in a single query — what would that tell you about your team's current workload distribution?

5. Has your organization ever delivered a job that was profitable on paper but a loss in practice? What information, captured at the estimate stage, might have predicted that outcome?

---

**[← Chapter 2: Capturing the Request](02-capturing-the-request.md)** | **[Next Chapter → Chapter 4: Quoting for Clarity](04-quoting-for-clarity.md)**
