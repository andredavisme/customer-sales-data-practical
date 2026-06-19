[← Table of Contents](TOC.md)

# Chapter 7: When Things Change

**Tier III** | *Adjustment types, root cause analysis, financial impact*

---

## Business Context

Every sales journey described in this textbook has assumed a clean path: request to estimate to quote to order to delivery. In practice, that path is rarely clean.

Prices get renegotiated after the order is placed. Delivery dates slip after the customer was already told a specific date. Quantities arrive short. Goods arrive damaged. Credits are issued. Cancellations happen. These are not anomalies — they are the normal friction of doing business, and they occur at every organization, at every scale, in every industry.

The question is not whether changes happen. The question is whether they are captured.

When a price is corrected via an email and never logged, that correction is invisible to analysis. When a delivery date changes for the fourth time on the same order, and each change overwrites the last, the pattern is gone — only the final value survives. When a credit is issued but not linked to the delivery or order it was correcting, the financial impact floats in a ledger with no operational context.

The `adjustment` table exists to make these changes visible, structured, and analyzable. It is the record of how reality diverged from the agreement — and what was done about it.

---

## The Adjustment Table in Context

The `adjustment` table was introduced in Tier I with a broad set of foreign keys and a handful of core fields. That structure was intentional: adjustments can originate at almost any point in the journey, so the table carries links to every upstream record.

Recall from Chapter 4: the boundary between a quote revision and an adjustment is the order. A quote revision (`qte_parent_id`, `qte_version`) handles changes made *before* the customer accepts. An adjustment handles changes made *after* acceptance — after the order exists.

The Tier I fields captured what changed (`adj_type`), why it changed (`adj_reason`), and the financial and date deltas (`adj_cost`, `adj_price`, `adj_del`). What they did not capture is the operational detail that makes adjustments analytically useful: who initiated the change, when it was approved, what its status is, and whether it triggered a financial obligation to the customer.

Tier III adds that operational layer.

---

## The Data Gap

With only Tier I `adjustment` data, you cannot answer:

- Who requested this adjustment — was it customer-initiated or internally identified?
- Who approved it, and when?
- Is this adjustment pending, approved, or already applied?
- Did this adjustment result in a credit to the customer?
- How many adjustments on this order were caused by the same root issue?
- What is the total financial impact of adjustments caused by late delivery across all orders this quarter?
- Which product categories generate the most price adjustments?
- Is there a pattern of adjustments clustering around a specific carrier, estimator, or customer type?

Each unanswered question represents a systemic problem that is happening, is costing money, and is invisible in the data.

---

## The Anatomy of an Adjustment

An adjustment has four components:

1. **What changed** — the type of adjustment (price, date, quantity, credit, cancellation)
2. **Why it changed** — the root cause (late delivery, damaged goods, pricing error, customer request)
3. **Who was involved** — who initiated it, who approved it
4. **What it cost** — the financial and operational impact

The Tier I table established the structural skeleton — the links and the basic what/why fields. Tier III fills in the operational and financial detail.

---

## Tier III Schema Additions: Adjustment

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| III | `adj_initiated_by` | Initiated By | FK → `user.user_id`; who logged or raised the adjustment; NULL if customer-initiated externally |
| III | `adj_initiated_date` | Initiated Date | When the adjustment was first recorded |
| III | `adj_approved_by` | Approved By | FK → `user.user_id`; who authorized the adjustment; NULL if not yet approved |
| III | `adj_approved_date` | Approved Date | When approval was granted |
| III | `adj_status` | Adjustment Status | Controlled vocabulary: Pending, Approved, Applied, Rejected, Cancelled |
| III | `adj_root_cause` | Root Cause | Structured classification: e.g., Carrier Delay, Estimating Error, Customer Change, Supplier Shortage, Damage in Transit, Pricing Error |
| III | `adj_credit_issued` | Credit Issued | Boolean: whether a financial credit was issued to the customer as part of this adjustment |
| III | `adj_credit_amount` | Credit Amount | The dollar value of any credit issued; NULL if no credit |
| III | `adj_source` | Adjustment Source | Controlled vocabulary: Customer-Initiated, Internal-Identified, Carrier-Claim, System-Generated |

### `adj_status`: Making Adjustments Operational

Without a status field, the adjustment table is a historical log. With it, the table becomes a workflow queue. `adj_status` answers the operational question: *what still needs to happen?*

- **Pending** — the adjustment has been logged but not yet reviewed or approved
- **Approved** — authorized but not yet applied to the relevant records
- **Applied** — the change has been made (price updated, credit issued, date revised)
- **Rejected** — reviewed and denied; the original terms stand
- **Cancelled** — the adjustment was withdrawn before a decision was made

A query filtering for `adj_status = 'Pending'` ordered by `adj_initiated_date` is the daily adjustment queue — the list of open items that need a decision.

### `adj_root_cause`: From Events to Patterns

`adj_reason` in Tier I is a free-text field — it captures what the person entering the adjustment thought was worth noting. That is useful for context. It is not useful for aggregation.

`adj_root_cause` is a structured classification field with a controlled vocabulary. Where `adj_reason` might say *"carrier picked up late due to weather, customer called to complain"*, `adj_root_cause` says `Carrier Delay`. The free-text note preserves the narrative. The structured field enables the query.

With `adj_root_cause` consistently populated, a single GROUP BY turns the adjustment log into a root cause analysis: how many adjustments, and how much financial impact, originated from each cause category. That is the query that turns operational data into organizational learning.

### `adj_source`: Who Is Driving the Changes

`adj_source` captures the origin of the adjustment request — not the cause of the underlying problem, but the trigger that surfaced it.

- **Customer-Initiated** — the customer raised the issue; this is reactive
- **Internal-Identified** — your team caught it proactively; this reflects operational discipline
- **Carrier-Claim** — originated from a carrier dispute or insurance process
- **System-Generated** — triggered automatically (e.g., a tolerance breach flagged by a rule in the database)

The ratio of Customer-Initiated to Internal-Identified adjustments is a quality culture metric. Organizations that catch their own errors before customers do are operating with higher internal standards. Organizations where most adjustments are customer-initiated are in a reactive posture — problems exist but are only surfaced when the customer complains.

### `adj_credit_issued` and `adj_credit_amount`: Financial Closure

Adjustments are not always free. A price correction may require a credit note. A late delivery may trigger a contractual penalty. A short-ship may result in a partial refund.

`adj_credit_issued` (boolean) and `adj_credit_amount` flag the financial obligation cleanly. Separating these from `adj_price` — which captures the price delta on the record itself — distinguishes between a price change (a correction to what was charged) and a credit (an additional financial concession to the customer). Both can occur on the same adjustment.

---

## Adjustment Types: What Changed

The `adj_type` field, present since Tier I, classifies the kind of change. A consistent controlled vocabulary here is what enables type-level analysis. The recommended vocabulary:

| adj_type | What It Represents |
|----------|--------------------|
| `Price` | A change to the agreed price on an order or line |
| `Date` | A revision to the committed delivery or completion date |
| `Quantity` | A change to the ordered or delivered quantity |
| `Credit` | A financial concession not tied to a specific price or quantity change |
| `Cancellation` | Full or partial cancellation of an order or line |
| `Substitution` | A different product or service delivered in place of the original |

Notice that `Substitution` is distinct from `Quantity`. A substitution means something *different* was delivered. A quantity adjustment means the right thing was delivered but in the wrong amount. Both affect the order, but they have different root causes and different downstream implications for inventory, customer satisfaction, and supplier management.

---

## The Adjustment as a Financial Record

The `adj_cost` and `adj_price` fields on the Tier I table capture the delta — the change in cost and price resulting from the adjustment. These are signed values: a negative `adj_price` means a price reduction; a positive `adj_price` means an increase.

The total financial impact of all adjustments on an order is the sum of those deltas:

```sql
SELECT
    ord_id,
    SUM(adj_price) AS total_price_adjustments,
    SUM(adj_cost)  AS total_cost_adjustments
FROM adjustment
WHERE adj_status = 'Applied'
GROUP BY ord_id;
```

Joining this to the original order gives you the **realized order value** — what was actually charged and what it actually cost, after all post-acceptance changes are accounted for.

This is the number that matters for margin analysis. An order that looked like 30% margin at the quote stage may have eroded to 18% by the time all adjustments were applied. Without the adjustment table, that erosion is invisible. With it, you can trace every step of the margin journey from estimate to final settlement.

---

## Analytical Application

### Open Adjustment Queue
*What needs a decision today?*

```sql
SELECT
    a.adj_id,
    a.adj_type,
    a.adj_root_cause,
    a.adj_source,
    c.cust_name,
    o.ord_id,
    a.adj_price                                          AS price_delta,
    a.adj_initiated_date,
    CURRENT_DATE - a.adj_initiated_date                  AS days_open,
    u.user_first_name || ' ' || u.user_last_name         AS initiated_by
FROM adjustment a
JOIN "order"   o ON a.ord_id   = o.ord_id
JOIN customer  c ON a.cust_id  = c.cust_id
LEFT JOIN "user" u ON a.adj_initiated_by = u.user_id
WHERE a.adj_status = 'Pending'
ORDER BY a.adj_initiated_date ASC;
```

This is the daily operations view for anyone managing the adjustment workflow. `days_open` surfaces how long each item has been sitting without a decision — the aging metric that prevents adjustments from quietly disappearing into a backlog.

---

### Root Cause Analysis: Frequency and Financial Impact
*Where are changes actually coming from, and what do they cost?*

```sql
SELECT
    a.adj_root_cause,
    a.adj_type,
    COUNT(a.adj_id)                             AS adjustment_count,
    ROUND(SUM(ABS(a.adj_price)), 2)             AS total_price_impact,
    ROUND(AVG(ABS(a.adj_price)), 2)             AS avg_price_impact,
    COUNT(CASE WHEN a.adj_credit_issued THEN 1 END) AS credits_issued,
    ROUND(SUM(COALESCE(a.adj_credit_amount, 0)), 2) AS total_credits
FROM adjustment a
WHERE a.adj_status = 'Applied'
GROUP BY a.adj_root_cause, a.adj_type
ORDER BY total_price_impact DESC;
```

This is the query that converts the adjustment log into organizational insight. The root causes with the highest total price impact are the systemic problems worth solving — not the loudest complaints, but the most expensive patterns. Pairing frequency with total impact distinguishes high-frequency low-cost issues (process friction) from low-frequency high-cost ones (structural failures).

---

### Margin Erosion: Quote to Final Settlement
*How much margin is lost between the accepted quote and the final realized order value?*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    c.cust_type,
    q.qte_price                                           AS quoted_price,
    o.ord_price                                           AS order_price,
    o.ord_cost                                            AS order_cost,
    COALESCE(SUM(a.adj_price), 0)                         AS total_price_adj,
    COALESCE(SUM(a.adj_cost),  0)                         AS total_cost_adj,
    o.ord_price + COALESCE(SUM(a.adj_price), 0)           AS realized_price,
    o.ord_cost  + COALESCE(SUM(a.adj_cost),  0)           AS realized_cost,
    ROUND(
        (o.ord_price + COALESCE(SUM(a.adj_price), 0)
        - o.ord_cost  - COALESCE(SUM(a.adj_cost),  0))
        / NULLIF(o.ord_price + COALESCE(SUM(a.adj_price), 0), 0) * 100
    , 2)                                                  AS realized_margin_pct
FROM "order" o
JOIN quote    q ON o.qte_id  = q.qte_id
JOIN customer c ON o.cust_id = c.cust_id
LEFT JOIN adjustment a ON a.ord_id = o.ord_id
                       AND a.adj_status = 'Applied'
GROUP BY o.ord_id, c.cust_name, c.cust_type, q.qte_price, o.ord_price, o.ord_cost
ORDER BY realized_margin_pct ASC;
```

Orders at the bottom of this list — lowest realized margin after all adjustments — are the deals that looked profitable at signing but were not. The pattern across those orders — by customer type, root cause, or product category — is the margin erosion story that finance and sales leadership need to see together.

---

### Customer-Initiated vs. Internal-Identified Adjustments by Quarter
*Are we catching our own problems — or waiting for customers to tell us?*

```sql
SELECT
    DATE_TRUNC('quarter', a.adj_initiated_date)          AS quarter,
    a.adj_source,
    COUNT(a.adj_id)                                      AS adjustment_count,
    ROUND(SUM(ABS(a.adj_price)), 2)                      AS total_price_impact
FROM adjustment a
WHERE a.adj_status IN ('Approved', 'Applied')
  AND a.adj_source IN ('Customer-Initiated', 'Internal-Identified')
GROUP BY DATE_TRUNC('quarter', a.adj_initiated_date), a.adj_source
ORDER BY quarter ASC, a.adj_source ASC;
```

A healthy trend shows Internal-Identified growing relative to Customer-Initiated over time — the organization is becoming more proactive. A worsening trend — customer-initiated share rising — signals that quality or process problems are outpacing the organization's ability to catch them internally.

---

### Delivery-Linked Adjustments: What Late Deliveries Actually Cost
*Isolating the financial impact of fulfillment failures.*

```sql
SELECT
    d.del_carrier,
    a.adj_root_cause,
    COUNT(a.adj_id)                                       AS adjustment_count,
    ROUND(SUM(ABS(a.adj_price)), 2)                       AS total_price_impact,
    ROUND(SUM(COALESCE(a.adj_credit_amount, 0)), 2)       AS total_credits_issued
FROM adjustment a
JOIN delivery d ON a.del_id = d.del_id
WHERE a.adj_root_cause IN ('Carrier Delay', 'Damage in Transit')
  AND a.adj_status = 'Applied'
GROUP BY d.del_carrier, a.adj_root_cause
ORDER BY total_price_impact DESC;
```

This query joins the adjustment table to the delivery table through `adj.del_id` — the foreign key that was present in the Tier I schema from the start. It surfaces the actual financial cost of each carrier's performance failures, not just their on-time rate. A carrier with a decent on-time rate but high credit exposure per late delivery is a different risk profile than one that is frequently late but rarely triggers a financial obligation.

---

## Reflection

1. Think about the last time a price was changed after an order was placed. Was that change logged anywhere in your system — or did it happen in an email, a phone call, or a verbal agreement that left no data trail? What would it take to make every post-acceptance price change a structured record?

2. In your current process, what is the most common reason for an adjustment? Is that pattern visible in your data, or is it something you know from experience because you see it repeatedly but cannot prove with a query?

3. Consider the distinction between `adj_reason` (free text, narrative) and `adj_root_cause` (structured classification). In your organization, who would be responsible for setting the controlled vocabulary for root causes? What are the five most important categories for your business?

4. Think about the ratio of customer-initiated to internally-identified adjustments in your current operation. If you had to estimate it, what would it be? What would it mean if you could measure it exactly — and what would you do if the number was worse than you expected?

5. The margin erosion query in this chapter traces the realized margin from quote to final settlement, including all applied adjustments. If you ran that query against your last year of orders, what do you think you would find? Which customer types or product categories do you suspect have the largest gap between quoted and realized margin?

---

**[← Chapter 6: Delivering on the Promise](06-delivering-on-the-promise.md)** | **[Next Chapter → Chapter 8: The Customer's Voice](08-the-customers-voice.md)**
