[← Table of Contents](TOC.md)

# Chapter 5: Managing the Order

**Tier II → III** | *Order lines, quantities, scheduling, partial fulfillment*

---

## Business Context

The quote has been accepted. The customer has said yes.

At this moment, the nature of the data changes. Everything up to this point — the request, the estimate, the quote — was prospective. It described what might happen. The order is the first record that describes what *will* happen. It is a commitment: your organization has agreed to deliver something specific, at a specific price, by a specific date.

The Tier I order table captured the skeleton of that commitment: a link to the accepted quote, a confirmed cost and price, and an expected delivery date. That is enough to know an order exists. It is not enough to manage one.

Consider an order for 200 units of three different products, split across two delivery locations, with one product back-ordered. A single record with a single delivery date and a single price cannot represent that reality. The moment operational complexity enters — and it always does — the header record alone collapses.

Chapter 5 builds the operational layer of the order: the line items that define what was ordered, the scheduling fields that govern when it will move, and the structures that allow an order to fulfill in parts without losing its integrity.

---

## The Data Gap

With the Tier I `order` table, here are the questions you cannot answer:

- What specific products or services are included in this order, and in what quantities?
- If an order ships in two deliveries, which line items were in each shipment?
- What delivery date did the customer request, versus what date was operationally promised?
- Which line items are back-ordered or delayed, and by how long?
- What is the fulfillment status of each line item independently?
- How does order composition compare to quote composition — were any items changed at order entry?

Each of these gaps becomes a problem the moment an order reaches operations. Without line-level detail, you cannot route, pick, schedule, or track individual items. Without scheduling fields, you cannot distinguish a customer-requested date from an internal operational target. Without partial fulfillment support, a single delayed line item holds the entire order hostage in your reporting.

---

## The Order as an Operational Contract

The quote was an artifact — a document sent to a customer. The order is an operational contract — an internal commitment that drives work.

This distinction shapes how the order table needs to be structured. A quote is prepared, sent, and either accepted or declined. An order is opened, worked against, updated as reality diverges from plan, and eventually closed when fulfilled. Its lifecycle is longer, messier, and more connected to other systems — inventory, scheduling, logistics, finance.

The data model must support that lifecycle. It does so through two mechanisms:

1. **Order lines** — breaking the order into its component items, each trackable independently
2. **Scheduling fields** — capturing the distinction between when the customer wants delivery and when operations can commit to it

Together, these two mechanisms transform the order from a static confirmation record into a living operational document.

---

## Introducing Order Lines

The `order_line` table mirrors the structure established in `estimate_line` and `quote_line`. One row per SKU per order. The total order is the sum of its lines.

But the order line carries something neither the estimate line nor the quote line does: **fulfillment state**. An estimate line has a cost and a price. A quote line has a customer-facing price. An order line has a quantity committed, a quantity fulfilled, and a status that tracks the gap between them.

This is where the transition from Tier II to Tier III begins. Tier II introduced line-level detail for internal costing (estimate) and external pricing (quote). Tier III extends line-level tracking into operational execution — what was committed versus what was delivered.

**`order_line` table:**

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `ord_ln_id` | Order Line ID | Primary key |
| II | `ord_id` | Order ID | FK → `order.ord_id` |
| II | `qte_ln_id` | Quote Line ID | FK → `quote_line.qte_ln_id`; the quote line this order line was confirmed from |
| II | `sku_id` | SKU ID | FK → `sku.sku_id` |
| II | `ord_ln_description` | Line Description | Confirmed description of the item or service |
| II | `ord_ln_qty_ordered` | Quantity Ordered | Committed quantity at order entry |
| II | `ord_ln_unit_price` | Unit Price | Confirmed price per unit |
| II | `ord_ln_total` | Line Total | Calculated: `ord_ln_qty_ordered` × `ord_ln_unit_price` |
| III | `ord_ln_qty_fulfilled` | Quantity Fulfilled | Cumulative quantity delivered against this line; updated as deliveries occur |
| III | `ord_ln_status` | Line Status | Controlled vocabulary: Open, Partial, Fulfilled, Cancelled, Back-Ordered |
| III | `ord_ln_notes` | Line Notes | Operational notes: substitutions, holds, special handling |

The split between Tier II and Tier III fields is deliberate. Tier II fields are set at order entry — they describe what was ordered. Tier III fields are updated during fulfillment — they describe what happened. This separation makes it easy to query the state of fulfillment at any point without confusing the original commitment with the operational outcome.

---

## Scheduling: Three Dates, Three Meanings

One of the most common sources of confusion in order management data is the conflation of multiple dates into a single field. "Delivery date" sounds like one thing. In practice, it is at least three:

| Date | Meaning | Who Sets It |
|------|---------|-------------|
| Customer-requested date | When the customer wants delivery | Customer, at the time of the original request |
| Promised date | What your organization committed to in the quote | Sales or quoting team |
| Operational target date | The internal working date based on actual capacity and scheduling | Operations |

The Tier I `ord_exp_date` field collapses all three into one. That works as long as they are always the same — which they rarely are.

A customer might request delivery by the 15th. The quote promises the 18th because of lead time. Operations schedules for the 17th to build in buffer. Three dates, three stakeholders, three legitimate views of the same event. A single field cannot represent all three without overwriting one with another.

### The Requested Date Lives in the Request

The customer-requested delivery date is not a new piece of information — it was captured at the very beginning of the journey. The `request` table, introduced in the Introduction and present since Tier I, is where the customer first expressed *what they need and when they need it*. That date belongs there, not duplicated on the order.

This is the data lineage principle in action. The order already carries `req_id` as a foreign key — a direct link back to the originating request. Rather than storing `ord_requested_date` as a separate field on the order, the requested date is retrieved by joining to the `request` table through that existing key. No new column is needed; the information is already in the chain.

The two dates that *are* new at the order stage — because they did not exist until the quote was accepted and operations engaged — are the promised date and the scheduled date:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `ord_promised_date` | Promised Delivery Date | The date committed to in the accepted quote; sourced from `qte_shipment_date` |
| II | `ord_scheduled_date` | Scheduled Delivery Date | Internal operational target; set by scheduling or operations |

*Note: `ord_exp_date` from Tier I is superseded by these two fields in Tier II. The requested date is accessed via `req_id → request`. The three-date view is assembled by joining all three sources.*

With all three dates accessible in the schema, you can answer questions that were previously invisible: How often does the promised date slip between quote acceptance and scheduling? How often do customers request dates that operations cannot meet? What is the average gap between the original request date and the final scheduled date by customer tier?

The SQL example in the Analytical Application section demonstrates how to assemble all three dates from their respective source tables in a single query.

---

## Partial Fulfillment

### When Orders Ship in Pieces

In practice, not every order ships in a single delivery. A back-ordered SKU delays one line. A customer requests a split shipment. A delivery route services one location before another. Partial fulfillment is not an edge case — it is the operational norm for any organization managing more than a handful of orders.

The data model must accommodate this without forcing the order into a false binary: fulfilled or not fulfilled.

Partial fulfillment is managed at two levels:

**At the line level:** `ord_ln_qty_fulfilled` tracks cumulative quantity delivered per line. `ord_ln_status` reflects whether a line is open, partially fulfilled, or complete. A line is not marked Fulfilled until `ord_ln_qty_fulfilled` equals `ord_ln_qty_ordered`.

**At the order level:** The order-level status reflects the aggregate state of its lines. An order is Open if no lines have shipped. It is Partial if some lines are fulfilled but others are not. It is Fulfilled only when every line reaches fulfilled status.

Two fields on the `order` table support this aggregate view:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| III | `ord_status` | Order Status | Controlled vocabulary: Open, Partial, Fulfilled, Cancelled, On Hold |
| III | `ord_fulfilled_date` | Fulfilled Date | Date the final line item was fulfilled; NULL until order is complete |

### Schema vs. Database Functions

The schema defines *what* data exists and *how it is structured*. It does not define *how that data is maintained*. These are separate concerns — and understanding the difference is one of the most practical distinctions in database design.

Consider `ord_status`. The schema says it exists, what values it can hold, and what it means. But the schema does not answer: *who updates it, and when?* Left to manual data entry, `ord_status` becomes unreliable — operators forget to update it, update it inconsistently, or update the header without touching the lines.

This is where **database functions** close the gap. A database function — or more specifically, a **trigger** — is a piece of logic that executes automatically in response to a data event. Rather than relying on a person or an application to remember to update `ord_status` whenever a line changes, a trigger can watch the `order_line` table and update the parent `order` record automatically:

- When the first `ord_ln_status` changes to `Partial` or `Fulfilled`, set `ord_status = 'Partial'`
- When all `ord_ln_status` values equal `Fulfilled`, set `ord_status = 'Fulfilled'` and stamp `ord_fulfilled_date = CURRENT_DATE`
- When any `ord_ln_status` is set to `Back-Ordered`, the order header can be flagged accordingly

Similarly, `ord_ln_total` — defined as `ord_ln_qty_ordered × ord_ln_unit_price` — is a **computed field**. Rather than storing a value that must be manually kept in sync with its inputs, a database function can calculate it on write or on read, guaranteeing it is always accurate.

Neither triggers nor computed fields change the schema. They are *implementations* of the schema — the database enforcing the rules that the schema describes. The schema tells you what data should look like when it is correct. Functions and triggers are the mechanisms that keep it correct without depending on human consistency.

This textbook defines the schema. The database implementation — including triggers, functions, constraints, and computed columns — is built in Phase II. What matters here is recognizing that every field marked as "updated as deliveries occur" or "calculated" in the schema tables is a candidate for automation in the database layer. The schema is the specification; the database is the enforcement.

---

## Tier II → III Schema Additions: Order

Complete set of Tier II and III additions to the `order` table:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `ord_promised_date` | Promised Delivery Date | Date committed in the accepted quote; sourced from `qte_shipment_date` |
| II | `ord_scheduled_date` | Scheduled Delivery Date | Internal operational target; set by operations |
| III | `ord_status` | Order Status | Open, Partial, Fulfilled, Cancelled, On Hold; maintained by trigger in Phase II |
| III | `ord_fulfilled_date` | Fulfilled Date | Date the final line was fulfilled; NULL until complete; stamped by trigger in Phase II |

*Note: The customer-requested date is accessed via `req_id → request` and does not require a separate column on the order.*

---

## Analytical Application

### Open Orders with Line-Level Fulfillment Status
*The operational dashboard view — what is in progress right now.*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    o.ord_promised_date,
    o.ord_scheduled_date,
    o.ord_status,
    COUNT(ol.ord_ln_id)                                            AS total_lines,
    COUNT(CASE WHEN ol.ord_ln_status = 'Fulfilled'    THEN 1 END) AS fulfilled_lines,
    COUNT(CASE WHEN ol.ord_ln_status = 'Back-Ordered' THEN 1 END) AS backordered_lines
FROM "order" o
JOIN customer c    ON o.cust_id = c.cust_id
JOIN order_line ol ON o.ord_id  = ol.ord_id
WHERE o.ord_status IN ('Open', 'Partial')
GROUP BY o.ord_id, c.cust_name, o.ord_promised_date, o.ord_scheduled_date, o.ord_status
ORDER BY o.ord_promised_date ASC;
```

This is the operations team's daily view: every active order, how many lines are fulfilled versus outstanding, and which ones have back-ordered items that may jeopardize the promised date.

---

### Three-Date View: Request, Promise, Schedule
*Assembling the full scheduling picture from its source tables.*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    r.req_delivery_date                                          AS customer_requested_date,
    o.ord_promised_date,
    o.ord_scheduled_date,
    o.ord_promised_date  - r.req_delivery_date                   AS promise_gap_days,
    o.ord_scheduled_date - o.ord_promised_date                   AS schedule_slip_days
FROM "order" o
JOIN customer c ON o.cust_id = c.cust_id
JOIN request  r ON o.req_id  = r.req_id
WHERE r.req_delivery_date IS NOT NULL
  AND o.ord_promised_date  IS NOT NULL
  AND o.ord_scheduled_date IS NOT NULL
ORDER BY promise_gap_days DESC;
```

This query joins across three source tables to assemble all three dates in one row — demonstrating how the foreign key chain (`ord_id → req_id → request`) makes the requested date accessible without storing it redundantly on the order.

---

### Promised Date vs. Scheduled Date Variance
*How often does operations slip the date between order acceptance and scheduling?*

```sql
SELECT
    c.cust_type,
    COUNT(o.ord_id)                                                          AS order_count,
    ROUND(AVG(o.ord_scheduled_date - o.ord_promised_date), 1)               AS avg_schedule_slip_days,
    COUNT(CASE WHEN o.ord_scheduled_date > o.ord_promised_date THEN 1 END)  AS orders_slipped,
    COUNT(CASE WHEN o.ord_scheduled_date <= o.ord_promised_date THEN 1 END) AS orders_on_or_early
FROM "order" o
JOIN customer c ON o.cust_id = c.cust_id
WHERE o.ord_scheduled_date IS NOT NULL
  AND o.ord_promised_date  IS NOT NULL
GROUP BY c.cust_type
ORDER BY avg_schedule_slip_days DESC;
```

A consistently positive `avg_schedule_slip_days` means the organization routinely promises dates that operations cannot meet. This is a quoting discipline problem, not an operations problem — and it is only visible when both dates are captured separately.

---

### Partial Fulfillment Rate by SKU
*Which products most commonly ship incomplete?*

```sql
SELECT
    s.sku_code,
    s.sku_name,
    COUNT(ol.ord_ln_id)                                                AS total_order_lines,
    COUNT(CASE WHEN ol.ord_ln_status = 'Partial'      THEN 1 END)     AS partial_lines,
    COUNT(CASE WHEN ol.ord_ln_status = 'Back-Ordered' THEN 1 END)     AS backordered_lines,
    ROUND(
        (COUNT(CASE WHEN ol.ord_ln_status IN ('Partial','Back-Ordered') THEN 1 END))::decimal
        / NULLIF(COUNT(ol.ord_ln_id), 0) * 100, 1
    )                                                                  AS incomplete_rate_pct
FROM order_line ol
JOIN sku s ON ol.sku_id = s.sku_id
GROUP BY s.sku_id, s.sku_code, s.sku_name
ORDER BY incomplete_rate_pct DESC;
```

SKUs with high incomplete rates are supply chain signals — chronic back-orders, unreliable lead times, or inaccurate inventory buffers. This query surfaces them before they become customer satisfaction issues.

---

### Order Value Variance: Quote vs. Order
*Did anything change between the accepted quote and the confirmed order?*

```sql
SELECT
    o.ord_id,
    c.cust_name,
    q.qte_price                          AS quoted_price,
    o.ord_price                          AS order_price,
    o.ord_price - q.qte_price            AS price_delta,
    ROUND(
        (o.ord_price - q.qte_price)
        / NULLIF(q.qte_price, 0) * 100, 2
    )                                    AS delta_pct
FROM "order" o
JOIN quote    q ON o.qte_id  = q.qte_id
JOIN customer c ON o.cust_id = c.cust_id
WHERE o.ord_price <> q.qte_price
ORDER BY ABS(o.ord_price - q.qte_price) DESC;
```

Orders that differ in price from their parent quote are an audit flag. A positive delta means the order was entered at a higher price than quoted — a potential overcharge. A negative delta means a discount was applied at order entry without a quote revision — a margin leak that bypassed the approval workflow.

---

## Reflection

1. Think about the most complex order your organization has fulfilled in the past year. How many distinct line items did it contain? How many deliveries did it take? Could your current data model reconstruct a complete picture of that order's fulfillment journey?

2. The customer's requested delivery date lives in the request — not the order. Does your current system preserve the original customer ask after the order is confirmed? If not, what is lost when that date is overwritten by the promised or scheduled date?

3. Consider a product that has been back-ordered more than once in the past six months. Is that pattern visible in your data? What would it take to surface it with a single query?

4. If an order ships in three partial deliveries over three weeks, how does your current system reflect the order's status at each stage? At what point does the order look "closed" in your data — and does that match when the customer considers it complete?

5. Think about the fields in this chapter that are described as "updated as deliveries occur" or "calculated." In your current environment, who is responsible for keeping those values current? How often are they wrong — and what would it take to make their maintenance automatic?

---

**[← Chapter 4: Quoting for Clarity](04-quoting-for-clarity.md)** | **[Next Chapter → Chapter 6: Delivering on the Promise](06-delivering-on-the-promise.md)**
