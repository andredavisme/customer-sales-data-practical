[← Table of Contents](TOC.md)

# Chapter 6: Delivering on the Promise

**Tier III** | *Delivery tracking, actual vs. promised dates, carrier data, partial shipments*

---

## Business Context

The order described what your organization committed to. The delivery describes what actually happened.

This is the moment the abstract becomes concrete. Every date comparison discussed in previous chapters — requested vs. promised, promised vs. scheduled — has been forward-looking. The delivery record is the first backward-looking entry in the journey: it captures reality, not intention. It is also the first record your customer experiences directly. They do not see your estimate, your internal margin calculations, or your scheduling variance. They see whether the product arrived, in the right quantity, on the date they needed it.

That asymmetry — between what you measured internally and what the customer experienced externally — is what makes the delivery table analytically powerful and operationally critical. Without it, you have no way to close the loop between what was promised and what was delivered.

---

## The Data Gap

The Tier I `delivery` table captured three things: a primary key, a link to the order, and a delivery date. That is the minimum viable record — enough to know a delivery occurred, not enough to understand it.

With only Tier I data, you cannot answer:

- Was this delivery on time relative to the promised date?
- Was it on time relative to what the customer originally requested?
- Did the delivery fulfill the entire order, or only part of it?
- Which specific order lines were included in this shipment?
- Who carried it, and by what method?
- If there were multiple deliveries against one order, which one completed it?
- Was anything delivered that was not on the order?

Each of these gaps has a cost. You cannot calculate an on-time delivery rate without knowing both the actual delivery date and the committed date. You cannot manage a multi-shipment order without knowing which lines were included in each delivery. You cannot evaluate a carrier without knowing who handled each shipment.

---

## What Makes a Delivery Record Complete

A complete delivery record captures four things:

1. **When** — the actual date the delivery reached the customer
2. **What** — which order lines, in what quantities, were included
3. **How** — the carrier, method, and tracking reference
4. **Against what commitment** — the promised date it is being measured against

The Tier I record had only the first. Tier III adds the rest.

---

## Actual vs. Promised: The Most Important Gap in Your Data

The single most valuable calculation in delivery analytics is also the simplest: `del_date - ord_promised_date`. The number of days between when you said it would arrive and when it actually did.

Positive means late. Negative means early. Zero means on time.

But this calculation only works if both dates are in the data and linked to the same record. The promised date lives on the `order` table. The actual delivery date lives on the `delivery` table. The foreign key `ord_id` on the delivery record is what connects them.

With that join in place, every delivery record becomes a performance measurement — not just a log entry.

The Tier I delivery table already carries `ord_id`. What it was missing was the additional fields to make the delivery record operationally complete. Those are added in Tier III.

---

## Tier III Schema Additions: Delivery

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| III | `del_type` | Delivery Type | Controlled vocabulary: Full, Partial, Final-Partial — whether this shipment completes the order |
| III | `del_carrier` | Carrier Name | The shipping carrier or internal delivery resource |
| III | `del_method` | Delivery Method | e.g., Ground, Express, Freight, Internal, Courier |
| III | `del_tracking` | Tracking Reference | Carrier tracking number or internal shipment ID |
| III | `del_notes` | Delivery Notes | Operational notes: access issues, substitutions, condition on arrival |

These five fields transform the delivery record from a timestamp into a shipment record. Each field answers a specific operational question that the Tier I record left open.

### `del_type`: Knowing Whether the Order Is Done

The most operationally important field in this table is `del_type`. It answers the question every operations and customer service team asks when a shipment goes out: *does this close the order?*

Three values cover the full range:

- **Full** — this single delivery fulfills the entire order
- **Partial** — this delivery fulfills some lines but more shipments are expected
- **Final-Partial** — this delivery is the last shipment; it may not have fulfilled every line completely (back-orders cancelled, substitutions accepted), but the order is considered closed

Without `del_type`, a delivery record is ambiguous. You cannot tell from the delivery date alone whether the order is done. `Final-Partial` is the structurally important edge case — it closes the order even when fulfillment was incomplete, capturing the real-world reality that not every order ends with 100% of every line shipped.

### `del_carrier` and `del_method`: Carrier Performance

Carrier name and delivery method are often treated as administrative fields — nice to have, not critical. In practice, they are the foundation of carrier performance analysis.

Once `del_carrier` and `del_date` are consistently captured, a simple aggregation reveals on-time delivery rate by carrier. That query — shown in the Analytical Application section — is one of the most actionable reports in operations. It surfaces which carriers are consistently late, which methods perform best by geography or order type, and where your logistics contracts may need to be renegotiated.

### `del_tracking`: The Audit Trail

`del_tracking` is a reference field — it links the delivery record to an external system (the carrier's tracking platform) or an internal logistics record. It does not drive calculations in your schema. Its value is as an audit trail: when a customer disputes a delivery, or when a shipment is lost, the tracking reference is the thread that connects your internal record to the physical world.

---

## Delivery Lines: Linking Shipments to Order Lines

For full delivery tracking — particularly in multi-shipment orders — a `delivery_line` table records which specific order lines were included in each shipment, and in what quantity.

This is the Tier III extension of the line-item pattern established in Chapters 3, 4, and 5. The `delivery_line` table does not introduce new operational data. It captures the mapping between delivery events and order commitments at the line level.

**`delivery_line` table:**

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| III | `del_ln_id` | Delivery Line ID | Primary key |
| III | `del_id` | Delivery ID | FK → `delivery.del_id` |
| III | `ord_ln_id` | Order Line ID | FK → `order_line.ord_ln_id`; which order line this delivery line fulfills |
| III | `del_ln_qty` | Quantity Delivered | The number of units delivered in this shipment for this line |
| III | `del_ln_notes` | Line Notes | Notes specific to this line in this delivery: substitutions, damages, short-ships |

### How Delivery Lines Update Order Lines

When a `delivery_line` record is created, it triggers an update to the corresponding `order_line`:

- `ord_ln_qty_fulfilled` increases by `del_ln_qty`
- `ord_ln_status` is recalculated: if `qty_fulfilled = qty_ordered`, the line is Fulfilled; if less, it remains Partial

When all `order_line` records for an order reach Fulfilled status — or when a `del_type` of `Final-Partial` is recorded — the parent `order` record transitions to Fulfilled and `ord_fulfilled_date` is stamped.

This is the trigger chain described in Chapter 5, now shown in its operational context. A single `delivery_line` insert propagates upward through `order_line` to `order`, keeping every level of the hierarchy consistent without manual intervention.

As with the order-level triggers, the schema defines the fields and their meaning. The trigger logic that maintains them is a Phase II database implementation concern. What the schema establishes is the structural dependency — the chain of records that must exist for the automation to be possible.

---

## Partial Delivery and Multi-Shipment Orders

Partial delivery is not a failure state — it is a normal operational pattern. Back-orders, phased delivery schedules, split shipments by location, and partial acceptance by the customer are all real-world scenarios that a single delivery record cannot represent.

The `delivery_line` table is what makes multi-shipment orders tractable. Each delivery against an order creates a new `delivery` header and the corresponding `delivery_line` rows. The order's fulfillment state is the aggregate of all delivery lines against all order lines.

Consider an order with three lines:
- Line 1: 50 units
- Line 2: 20 units
- Line 3: 10 units

First delivery: Lines 1 and 2 ship in full. `del_type = Partial`. Order status: Partial.
Second delivery: Line 3 ships. `del_type = Final-Partial` (or Full, if everything was fulfilled). Order status: Fulfilled. `ord_fulfilled_date` stamped.

Without `delivery_line`, the second delivery looks identical to the first — a timestamp against an order ID. With `delivery_line`, you can reconstruct the complete fulfillment sequence, line by line, shipment by shipment.

---

## The Delivery Record and the Customer's Experience

The delivery table sits at the boundary between your internal operations and your customer's reality. Every date comparison it enables — actual vs. promised, actual vs. requested — is a measure of the gap between your commitment and the customer's experience.

This positions the delivery table as the natural precursor to the `response` table (Chapter 8). The response record captures how the customer reacted. The delivery record captures what they reacted to. The two together form a complete feedback loop: what was delivered, and how it was received.

It also connects back to the `adjustment` table (Chapter 7). When a delivery falls short — wrong quantity, damaged goods, late arrival — an adjustment is the mechanism for correcting the record and the relationship. The delivery record is the evidence the adjustment references.

---

## Analytical Application

### On-Time Delivery Rate by Month
*The headline operations metric — what percentage of deliveries met the promised date?*

```sql
SELECT
    DATE_TRUNC('month', d.del_date)                              AS delivery_month,
    COUNT(d.del_id)                                              AS total_deliveries,
    COUNT(CASE WHEN d.del_date <= o.ord_promised_date THEN 1 END) AS on_time,
    ROUND(
        COUNT(CASE WHEN d.del_date <= o.ord_promised_date THEN 1 END)::decimal
        / NULLIF(COUNT(d.del_id), 0) * 100, 1
    )                                                            AS on_time_pct
FROM delivery d
JOIN "order" o ON d.ord_id = o.ord_id
WHERE o.ord_promised_date IS NOT NULL
GROUP BY DATE_TRUNC('month', d.del_date)
ORDER BY delivery_month ASC;
```

This is the delivery equivalent of the conversion rate query in Chapter 4. One number — on-time delivery percentage — summarizes the organization's fulfillment reliability over time. Trending it monthly reveals whether performance is improving, deteriorating, or seasonal.

---

### On-Time Delivery Rate by Carrier
*Which carriers are actually reliable?*

```sql
SELECT
    d.del_carrier,
    d.del_method,
    COUNT(d.del_id)                                                AS total_deliveries,
    COUNT(CASE WHEN d.del_date <= o.ord_promised_date THEN 1 END)  AS on_time,
    ROUND(
        COUNT(CASE WHEN d.del_date <= o.ord_promised_date THEN 1 END)::decimal
        / NULLIF(COUNT(d.del_id), 0) * 100, 1
    )                                                              AS on_time_pct,
    ROUND(AVG(d.del_date - o.ord_promised_date), 1)               AS avg_days_variance
FROM delivery d
JOIN "order" o ON d.ord_id = o.ord_id
WHERE d.del_carrier IS NOT NULL
  AND o.ord_promised_date IS NOT NULL
GROUP BY d.del_carrier, d.del_method
ORDER BY on_time_pct DESC;
```

`avg_days_variance` is the richer signal. A carrier with 90% on-time but an average variance of +4 days when late is less concerning than one with 85% on-time but +12 days variance — because the lateness, when it happens, is severe. Both the rate and the magnitude matter for carrier evaluation.

---

### Full Delivery Journey: Requested → Promised → Actual
*The complete date chain for every closed order.*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    r.req_delivery_date                             AS customer_requested,
    o.ord_promised_date                             AS promised,
    d.del_date                                      AS actual,
    o.ord_promised_date - r.req_delivery_date       AS promise_gap_days,
    d.del_date          - o.ord_promised_date       AS delivery_variance_days,
    d.del_date          - r.req_delivery_date       AS total_gap_from_request
FROM delivery d
JOIN "order"  o ON d.ord_id  = o.ord_id
JOIN request  r ON o.req_id  = r.req_id
JOIN customer c ON o.cust_id = c.cust_id
WHERE d.del_type IN ('Full', 'Final-Partial')
  AND r.req_delivery_date  IS NOT NULL
  AND o.ord_promised_date  IS NOT NULL
ORDER BY total_gap_from_request DESC;
```

Filtering to `Full` and `Final-Partial` delivery types ensures one row per closed order — the final state of the delivery chain. `total_gap_from_request` is the number that matters most to the customer: how far the actual delivery landed from what they originally asked for.

---

### Multi-Shipment Orders: Delivery Count and Completion Timeline
*Which orders required the most deliveries to fulfill?*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    COUNT(d.del_id)                          AS delivery_count,
    MIN(d.del_date)                          AS first_delivery,
    MAX(d.del_date)                          AS final_delivery,
    MAX(d.del_date) - MIN(d.del_date)        AS fulfillment_span_days,
    o.ord_promised_date,
    MAX(d.del_date) - o.ord_promised_date    AS final_delivery_variance
FROM delivery d
JOIN "order"  o ON d.ord_id  = o.ord_id
JOIN customer c ON o.cust_id = c.cust_id
GROUP BY o.ord_id, c.cust_name, o.ord_promised_date
HAVING COUNT(d.del_id) > 1
ORDER BY delivery_count DESC, fulfillment_span_days DESC;
```

`fulfillment_span_days` measures how long it took to complete an order that required multiple shipments. Combined with `final_delivery_variance`, it distinguishes between multi-shipment orders that were well-managed (short span, on-time final delivery) and those that dragged — signals of supply chain fragility or scheduling failures.

---

### Line-Level Fulfillment Completeness
*Did every line get fully delivered — or did some fall short?*

```sql
SELECT
    ol.ord_ln_id,
    o.ord_id,
    c.cust_name,
    s.sku_code,
    s.sku_name,
    ol.ord_ln_qty_ordered,
    COALESCE(SUM(dl.del_ln_qty), 0)              AS qty_delivered,
    ol.ord_ln_qty_ordered
    - COALESCE(SUM(dl.del_ln_qty), 0)            AS qty_shortfall,
    ol.ord_ln_status
FROM order_line ol
JOIN "order"      o  ON ol.ord_id   = o.ord_id
JOIN customer     c  ON o.cust_id   = c.cust_id
JOIN sku          s  ON ol.sku_id   = s.sku_id
LEFT JOIN delivery_line dl ON ol.ord_ln_id = dl.ord_ln_id
GROUP BY ol.ord_ln_id, o.ord_id, c.cust_name, s.sku_code, s.sku_name,
         ol.ord_ln_qty_ordered, ol.ord_ln_status
HAVING ol.ord_ln_qty_ordered > COALESCE(SUM(dl.del_ln_qty), 0)
ORDER BY qty_shortfall DESC;
```

This query surfaces every order line where quantity delivered fell short of quantity ordered. Combined with `ord_ln_status`, it distinguishes lines that are still open (more deliveries expected) from lines that were closed short (Final-Partial orders where the shortfall was accepted). The shortfall column feeds directly into the adjustment analysis in Chapter 7.

---

## Reflection

1. Think about the last delivery complaint you received from a customer. Was the issue a late delivery, a partial delivery, or something else? Is that distinction visible in your current data — or does every delivery look the same regardless of what went wrong?

2. Your organization likely uses more than one carrier. Do you currently have a way to compare on-time performance across carriers by method? If not, what decisions are being made about logistics contracts without that data?

3. Consider an order that required three deliveries to complete. In your current system, is it possible to reconstruct the sequence — which lines shipped when, in what quantities, and which delivery closed the order? What gaps would you find?

4. The `del_type` field distinguishes Full, Partial, and Final-Partial deliveries. Think about a recent order that closed without everything being delivered — a back-order that was eventually cancelled, a substitution that was accepted. How was that closure recorded? Where did the shortfall go?

5. The delivery record is the last internal record before the customer's experience. The next chapter covers the adjustment — what happens when that experience produces a discrepancy. Think about a recent case where a delivery triggered a correction. What data would you need from the delivery record to support that adjustment clearly?

---

**[← Chapter 5: Managing the Order](05-managing-the-order.md)** | **[Next Chapter → Chapter 7: When Things Change](07-when-things-change.md)**
