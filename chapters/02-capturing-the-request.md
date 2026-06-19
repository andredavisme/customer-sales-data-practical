[← Table of Contents](TOC.md)

# Chapter 2: Capturing the Request

**Tier I → II** | *Request types, product vs. service workflows, request metadata*

---

## Business Context

The request is the beginning of everything. Before there is an estimate, a quote, an order, or a delivery, there is a customer who asked for something. How well you capture that ask determines how cleanly the rest of the data chain flows.

Tier I gives you three fields to describe a request: a type, a free-text description, and the customer it belongs to. That is enough to know a request happened. It is not enough to understand *what kind* of request it was, *when* it came in, *how* it arrived, or *how urgent* the customer considers it.

Think about what happens when a request moves through your organization without that context. An operations team picks up a service request and begins scheduling technicians — only to learn it was actually a product inquiry that should have gone to the warehouse. A high-priority customer submits a request through a web form and it sits in the same queue as routine reorders. A request that came in six weeks ago has no timestamp, so nobody knows whether the follow-up is overdue by days or by months.

These are not edge cases. They are the daily reality of organizations that treat the request as a formality rather than a data event.

---

## The Data Gap

With the Tier I `request` table, here are the questions you cannot reliably answer:

- When was this request submitted?
- Is this a product request or a service request, and does it need to be routed differently?
- How did the request reach us — phone, email, portal, in-person?
- How urgent is this request, and does urgency match how we are treating it?
- Which requests are still open, and for how long?
- Who on our side is responsible for following up?
- When does the customer need delivery — and how does that compare to what we ultimately promised?

The Tier I `req_type` field touches on some of these, but a single classification cannot answer all of them. Type describes *what* was requested. Channel describes *how* it arrived. Priority describes *how urgently* it is needed. Status describes *where it stands now*. These are four distinct dimensions and they belong in four distinct fields.

---

## Products vs. Services: Why the Distinction Matters

Not all requests are the same, and the most fundamental split is between requests for a **product** and requests for a **service**.

A product request initiates a fulfillment workflow: inventory is checked, an item is picked, packed, and shipped. The downstream records — estimate, quote, order, delivery — are primarily concerned with quantities, SKUs, lead times, and shipping logistics.

A service request initiates a scheduling and labor workflow: availability is checked, a technician or consultant is assigned, time is allocated, and the delivery is measured in hours or outcomes rather than units. The downstream records carry different fields, different cost structures, and different delivery metrics.

When both request types flow through the same pipeline without being distinguished, your analysis blurs. Average lead times become meaningless when they average installation projects with product reorders. Delivery rates become misleading when a shipped package and a completed service call are counted the same way.

The Tier I `req_type` field can hold this distinction if it is used consistently. Tier II formalizes it by separating *request category* (the product/service split) from *request type* (the specific classification within that category), so each dimension can be analyzed independently.

---

## Request Metadata: The Four Dimensions

Every request has context that is not captured in its description. That context — collectively called metadata — is what turns a request from a note into a manageable, analyzable data record.

### When: The Submission Date

`req_date` is the timestamp of when the request was received. It is the anchor for every SLA calculation, every aging report, and every response time metric. Without it, you cannot answer the most basic operational question: *how long have we been sitting on this?*

This field should be populated automatically by the system at the moment of entry, not manually by the person entering it. Manual date entry is a source of error and a temptation for retroactive editing.

### When They Need It: The Requested Delivery Date

`req_delivery_date` is the customer's stated target for when they need delivery. It is a different kind of date than `req_date` — one is about when the request arrived at your organization, the other is about when the customer expects a result.

This date is the origin point of the entire scheduling chain. Every downstream date — the estimate's projected delivery, the quote's committed date, the order's promised and scheduled dates — can be measured against it. Without `req_delivery_date` anchored in the request, the only way to know what the customer originally asked for is to ask them again.

Capturing it here, at the earliest point in the journey, means it is never lost. Whether the request was submitted by phone, portal, or in person, the customer's expectation is on record — and every subsequent commitment can be evaluated against it.

### How: The Source Channel

`req_channel` records how the request arrived — phone, email, web portal, in-person, EDI, or any other channel your organization uses. Channel data answers questions that are invisible without it:

- Which channel generates the most requests? The most profitable ones?
- Are portal requests processed faster than phone requests?
- Is a particular channel producing lower-quality requests that require more clarification before they can move forward?

Channel data also informs investment decisions. If 70% of your requests come through a web portal but 80% of your high-value requests come through direct sales calls, that has implications for where you staff and where you build.

### How Urgent: Priority

`req_priority` is the customer's stated or inferred urgency. Common values are High, Medium, and Low, though your organization may use numeric scales or SLA tier labels.

Priority is not the same as importance. A low-priority request from your highest-value account may warrant more attention than a high-priority request from a one-time buyer. Priority is one input into a routing and scheduling decision — it should inform that decision, not make it automatically.

The analytical value of priority lies in the gap between stated priority and actual handling. Requests marked High that sit for two weeks reveal a capacity problem. Requests marked Low that get expedited reveal inconsistent process discipline. The data tells the story if the field is populated honestly.

### Where It Stands: Status

`req_status` tracks the current state of the request in your workflow. Typical values include: Open, In Review, Pending Information, Converted, Closed — Fulfilled, Closed — Declined.

Status is the field that makes a request list operational rather than historical. Without it, you cannot filter for what needs action today. With it, you can build a live queue, measure conversion rates from request to order, and identify where requests stall in your process.

A request that is "Converted" has become an estimate or an order. Its job in the request table is done; the downstream tables carry it forward. A request that has been "Open" for thirty days with no status change is a signal worth investigating.

---

## Assigning Ownership

A request without an owner is a request that belongs to no one. `req_owner` is the internal user or team responsible for responding to and advancing the request. It is the field that makes accountability visible in your data.

Ownership is often managed outside the data — in email inboxes, in verbal assignments, in team meetings. The cost of that approach is that when something falls through the cracks, there is no data record of who was responsible. With `req_owner` in the schema, you can measure response rates by owner, identify bottlenecks by team, and hold the process accountable with numbers rather than memory.

---

## Tier II Schema Updates

### Updated: `request` Table

New attributes added in Tier II:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `req_date` | Request Date | Timestamp of when the request was received; system-generated |
| II | `req_category` | Request Category | Broad classification: Product or Service |
| II | `req_channel` | Request Channel | How the request arrived: e.g., Phone, Email, Portal, In-Person, EDI |
| II | `req_priority` | Request Priority | Urgency classification: e.g., High, Medium, Low |
| II | `req_status` | Request Status | Current workflow state: e.g., Open, In Review, Converted, Closed |
| II | `req_owner` | Request Owner | FK → `user.user_id`; internal user responsible for the request |

*Note: `req_delivery_date` was established in Tier I (see Introduction). It is referenced throughout this chapter as the scheduling anchor for the metadata fields introduced here — but it requires no new addition to the schema.*

---

## Analytical Application

### How many open requests do we have, by priority?

```sql
SELECT
  req_priority,
  COUNT(req_id) AS open_requests
FROM request
WHERE req_status = 'Open'
GROUP BY req_priority
ORDER BY
  CASE req_priority
    WHEN 'High'   THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'Low'    THEN 3
  END;
```

### What is the average age of open requests by channel?

```sql
SELECT
  req_channel,
  ROUND(AVG(CURRENT_DATE - req_date::DATE), 1) AS avg_days_open
FROM request
WHERE req_status = 'Open'
GROUP BY req_channel
ORDER BY avg_days_open DESC;
```

This query surfaces channel-level processing differences. If portal requests average 4 days open and phone requests average 14, that is an operational signal — not just a curiosity.

### What is the request-to-order conversion rate by category?

```sql
SELECT
  r.req_category,
  COUNT(DISTINCT r.req_id)                              AS total_requests,
  COUNT(DISTINCT o.ord_id)                              AS converted_to_order,
  ROUND(
    COUNT(DISTINCT o.ord_id)::NUMERIC /
    NULLIF(COUNT(DISTINCT r.req_id), 0) * 100, 1
  )                                                     AS conversion_pct
FROM request r
LEFT JOIN "order" o ON r.req_id = o.req_id
GROUP BY r.req_category;
```

Conversion rate by category reveals whether product requests and service requests close at different rates — and if so, at what stage in the pipeline they diverge.

### Which owners have the most requests stalled in review?

```sql
SELECT
  u.user_first_name || ' ' || u.user_last_name AS owner_name,
  COUNT(r.req_id)                              AS stalled_requests,
  ROUND(AVG(CURRENT_DATE - r.req_date::DATE), 1) AS avg_days_in_review
FROM request r
JOIN "user" u ON r.req_owner = u.user_id
WHERE r.req_status = 'In Review'
GROUP BY u.user_id, owner_name
ORDER BY stalled_requests DESC;
```

### How far in advance do customers typically request delivery?

```sql
SELECT
  req_channel,
  ROUND(AVG(req_delivery_date - req_date::DATE), 1) AS avg_lead_days_requested
FROM request
WHERE req_delivery_date IS NOT NULL
  AND req_date IS NOT NULL
GROUP BY req_channel
ORDER BY avg_lead_days_requested ASC;
```

This query measures the natural lead time customers are building into their requests by channel. Short average lead times by channel signal that customers expect fast turnaround — and that your quoting and scheduling teams need to be ready for it.

---

## Reflection

1. How does your organization currently distinguish between product and service requests? Is that distinction captured in your data, or does it live in someone's head or inbox?

2. Look at the last ten requests your team processed. Could you reconstruct when each one arrived, how it arrived, who was responsible for it, and when the customer needed delivery? If not, which field would have made the biggest difference?

3. What does your current request-to-order conversion rate look like? If you cannot calculate it, what does that tell you about your request data?

4. Think about a request that stalled or fell through the cracks in the past year. Which of the Tier II fields added in this chapter — date, category, channel, priority, status, owner — would have made that request visible before it became a problem?

5. Consider the gap between when customers submit requests and when they say they need delivery. Does that gap vary by channel, by customer type, or by product category? What would knowing that gap tell you about your quoting and scheduling capacity?

---

**[← Chapter 1: Knowing Your Customer](01-knowing-your-customer.md)** | **[Next Chapter → Chapter 3: Estimating with Confidence](03-estimating-with-confidence.md)**
