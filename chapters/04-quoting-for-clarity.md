[← Table of Contents](TOC.md)

# Chapter 4: Quoting for Clarity

**Tier II** | *Quote versioning, approval workflows, expiry tracking, data vs. artifacts*

---

## Business Context

The estimate was an internal document. The quote is the first artifact the customer sees.

That distinction changes everything. An estimate is typically the result of an internal conversation — a working analysis of cost, feasibility, and timing. It may be captured in your system, discussed informally, revised in a meeting, or summarized in an email thread. Whether the customer ever sees it, or in what form, varies widely by industry and organization.

A quote is different. In the real world, a quote is almost certainly a shared document: a PDF, a formal letter, an email with attached pricing, or a portal-generated summary. It carries your organization's name, a price, a delivery commitment, and an implied promise. Once sent, it creates expectations. Once accepted, it becomes the contractual foundation of the order.

---

## Data and Artifacts: The Distinction That Matters

The quote introduces a concept that will recur throughout this textbook: the difference between **data** and **artifacts**.

**Data** is the structured record your organization owns, secures, and controls. It lives in your database. It is referenced by other records, joined in queries, and governed by your access policies. The quote record in your schema — with its fields, foreign keys, and version history — is data.

**An artifact** is the presentation of that data, formatted for a specific audience and purpose. A quote document sent to a customer is an artifact. It is derived from the data, but it is not the data itself. It is a snapshot — a rendered view at a point in time, shaped for external consumption.

This distinction matters for several reasons:

- **The data outlives the artifact.** A quote PDF may be deleted, lost, or never saved. The data record persists, traceable and auditable. This is why the schema must capture everything of operational value — not assume the document will always be available.
- **The artifact is shaped for its audience.** A quote document shows the customer price, the delivery date, and the item descriptions they need to make a decision. It does not show your internal cost, your margin targets, or your alert flags. The same underlying data produces different artifacts for different audiences.
- **Data is owned; artifacts are shared.** Your organization controls the schema, the access rules, and the version history. What the customer receives is a controlled release of selected information — not access to the record itself.

The estimate existed entirely in the internal sphere. The quote crosses the boundary. From this point forward in the journey — quote, order, delivery, response — every record has a potential external representation. The discipline of separating what is stored from what is shared is what keeps that boundary intact.

---

## The Data Gap

With the Tier I `quote` table, here are the questions you cannot answer:

- How many revisions did this quote go through before acceptance?
- What changed between quote versions?
- Who approved this quote before it was sent?
- How many active quotes have passed their validity date?
- How long does it typically take customers to respond to a quote?
- Which approver has the highest conversion rate?

Each of these gaps is operationally expensive. Missing revision history obscures negotiation patterns. Absent expiry tracking lets outdated quotes linger in open pipelines. No approval record means no audit trail between the estimate and the document delivered to the customer.

---

## Quote Versioning

### The Revision Problem

In practice, quotes are rarely accepted on the first draft. Pricing gets negotiated. Delivery dates shift. Line items get added or removed. In a Tier I schema where each quote is a single mutable record, every revision destroys the history of what came before it.

The solution is a **self-referencing parent key** — the same pattern introduced for account hierarchy in Chapter 1.

A new column `qte_parent_id` references `qte_id` in the same table. The original quote has no parent (`NULL`). Each revision points back to the quote it superseded.

A companion integer column `qte_version` makes the sequence explicit: version 1 is the original, version 2 is the first revision, and so on. The active quote is always the highest version number within a `qte_parent_id` group.

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_parent_id` | Parent Quote ID | FK → `quote.qte_id`; NULL on original; points to prior version on revisions |
| II | `qte_version` | Quote Version | Integer; 1 = original, increment per revision |

**Why this matters:** When a deal closes, you can now trace the full revision history — how many versions it took, what changed at each step, and whether the final price was above or below the initial offer. This is the negotiation audit trail that every sales manager wants but almost no one has captured cleanly.

### Revisions vs. Adjustments: Where Each Belongs

The quote revision mechanism — `qte_parent_id` and `qte_version` — handles one specific kind of change: changes made *before the quote is accepted*. These are negotiation-stage revisions. The customer has not yet said yes. No order exists. The revision is part of the quoting process itself.

The `adjustment` table, introduced in Tier I, handles a fundamentally different kind of change: changes made *after agreement has been reached*. An adjustment is a correction to something that was already operational — a committed order, a completed delivery, a fulfilled price.

The boundary between them is the order. Once a quote is accepted and an order is created, the negotiation is closed. Any subsequent change to price, quantity, delivery date, or terms is no longer a quote revision — it is an adjustment against the order or delivery record.

| Mechanism | Timing | Trigger | Recorded In |
|-----------|--------|---------|-------------|
| Quote revision (`qte_parent_id` / `qte_version`) | Pre-acceptance | Negotiation, scope change, pricing update | `quote` table — new row per version |
| Adjustment (`adj_*`) | Post-acceptance | Price correction, date change, quantity change, credit | `adjustment` table — linked to `ord_id` or `del_id` |

This separation keeps each table clean and purposeful. The `quote` table tells the story of how an agreement was reached. The `adjustment` table tells the story of how reality diverged from that agreement after the fact.

A practical test: *"Has the customer said yes yet?"* If no — use a quote revision. If yes — use an adjustment.

---

## Approval Workflows

### Authorization Before Delivery

Not every quote should leave your organization without a second set of eyes. Discounts beyond a threshold, unusually long payment terms, or delivery commitments that stretch capacity all warrant review. Approval workflows formalize this gatekeeping in the data.

Three fields capture the complete approval record:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_prepared_by` | Prepared By | FK → `user.user_id`; who built the quote |
| II | `qte_approved_by` | Approved By | FK → `user.user_id`; who authorized it for delivery; NULL if not yet approved |
| II | `qte_approved_date` | Approval Date | Date approval was granted; NULL if pending |

Both ownership fields reference the `user` table introduced in Chapter 3 — the same table anchoring `req_owner` and `est_prepared_by`. The user table continues to do its job: providing a single, consistent identity reference across every step in the journey.

**The diagnostic signal:** A quote with `qte_approved_by` populated but `qte_approved_date` as NULL is a data quality flag — it suggests someone was recorded as the approver but no date was logged. A query targeting this pattern surfaces either a process gap (approvals happening verbally without documentation) or a data entry issue.

**The analytical payoff:** Once both fields are consistently populated, you can compare conversion rates by approver. If quotes approved by one manager convert at 60% and another at 35%, that is a coaching signal — or a pricing strategy signal — worth investigating.

---

## Quote Expiry

### The Silent Aging Problem

Quotes have a shelf life. Costs change. Supplier pricing fluctuates. Capacity fills. A quote issued six months ago may no longer reflect what it would cost to fulfill today — but without an expiry mechanism, nothing in the data flags that it has gone stale.

Two fields address this:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_valid_until` | Valid Until Date | The date the quote is no longer actionable without reissue |
| II | `qte_expiry_action` | Expiry Action | Controlled vocabulary: Renewed, Cancelled, Expired-No-Action, Superseded |

`qte_valid_until` is the operational anchor. A daily query filtering for quotes where `qte_valid_until < CURRENT_DATE` and no expiry action has been recorded produces the action list for the day.

`qte_expiry_action` is the disposition record. Rather than letting expired quotes accumulate ambiguously, this field captures what actually happened: was the quote renewed with updated pricing? Cancelled by the customer? Did it simply expire with no follow-up? Or was it superseded by a revision?

**Why a structured field matters here:** Free-text notes decay into illegibility over time. A structured `qte_expiry_action` with a controlled vocabulary makes the question *"how many quotes expired with no action in Q2?"* answerable with a single WHERE clause.

---

## Tracking the Conversation: Sent and Response Dates

The quote artifact travels from your organization to the customer. Before it is sent, there is the moment it was created: **`qte_date`** — the timestamp when the quote record was generated, system-set at creation and never changed. It is the reference point for every pipeline age calculation, response time metric, and expiry window measurement the quote will ever participate in.

From there, two more dates close the loop on the conversation:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_sent_date` | Sent Date | Date the quote was delivered to the customer |
| II | `qte_response_date` | Response Date | Date the customer replied (accepted, rejected, or countered) |

The gap between `qte_sent_date` and `qte_response_date` is the customer's decision window. Patterns in that window — by customer type, by approver, by quote value — inform follow-up cadence and pipeline forecasting.

---

## Linking to Estimates

The quote does not exist in isolation. It is the externalization of the internal estimate — and the relationship between them is worth tracking explicitly.

A direct foreign key `qte_est_id` links the quote to the estimate it was built from. This enables the **price integrity check**: did the quote accurately reflect the estimated cost and margin?

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_est_id` | Estimate ID | FK → `estimate.est_id`; the estimate this quote was derived from |

With this link in place, a query comparing `qte_price` to `est_price` across all quotes will surface the delta — how often quotes went out above or below the estimate, and by how much. Patterns of systematic underquoting relative to estimates are a margin erosion signal that is invisible without this join.

---

## Quote Lines

Just as the estimate introduced `estimate_line` to capture item-level cost detail, the quote introduces a parallel `quote_line` table. The distinction is audience: estimate lines hold internal cost logic; quote lines hold the customer-facing representation of the same items.

This is the artifact boundary applied at the line level. The customer sees descriptions, quantities, and prices. They do not see the underlying cost, margin calculations, or SKU catalog entries that informed those numbers.

**`quote_line` table:**

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_ln_id` | Quote Line ID | Primary key |
| II | `qte_id` | Quote ID | FK → `quote.qte_id` |
| II | `est_line_id` | Estimate Line ID | FK → `estimate_line.est_line_id`; the estimate line this quote line corresponds to |
| II | `qte_ln_description` | Line Description | Customer-facing description of the item or service |
| II | `qte_ln_qty` | Quantity | Quoted quantity |
| II | `qte_ln_unit_price` | Unit Price | Price per unit as presented to the customer |
| II | `qte_ln_total` | Line Total | Calculated: `qte_ln_qty` × `qte_ln_unit_price` |

The link to `est_line_id` is structurally important — it connects each quote line back to the estimate line it was priced from, enabling line-level price-to-cost comparison rather than just a header-level delta.

---

## Tier II Schema Additions: Quote

Complete set of Tier II additions to the `quote` table:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| II | `qte_date` | Quote Date | Timestamp when the quote was created; system-generated |
| II | `qte_status` | Quote Status | Controlled vocabulary: Draft, Sent, Accepted, Cancelled — the current lifecycle state of the quote |
| II | `qte_est_id` | Estimate ID | FK → `estimate.est_id`; estimate this quote was derived from |
| II | `qte_parent_id` | Parent Quote ID | FK → `quote.qte_id`; NULL on original; prior version on revisions |
| II | `qte_version` | Quote Version | Integer; 1 = original |
| II | `qte_prepared_by` | Prepared By | FK → `user.user_id`; who built the quote |
| II | `qte_approved_by` | Approved By | FK → `user.user_id`; who authorized it |
| II | `qte_approved_date` | Approval Date | Date of approval |
| II | `qte_sent_date` | Sent Date | Date delivered to the customer |
| II | `qte_response_date` | Response Date | Date customer replied |
| II | `qte_valid_until` | Valid Until Date | Expiry date |
| II | `qte_expiry_action` | Expiry Action | Renewed, Cancelled, Expired-No-Action, Superseded |

*Note: `qte_est_id` supersedes `est_id` from Tier I on the `quote` table. The `qte_` prefix aligns this field with the consistent naming convention applied to all quote-level attributes in Tier II.*

---

## Analytical Application

### Expired Quotes Without a Closed Status
*The daily operations query — what needs attention today.*

```sql
SELECT
    q.qte_id,
    q.qte_version,
    c.cust_name,
    q.qte_price,
    q.qte_valid_until,
    u.user_first_name || ' ' || u.user_last_name AS prepared_by
FROM quote q
JOIN customer c ON q.cust_id = c.cust_id
JOIN "user" u ON q.qte_prepared_by = u.user_id
WHERE q.qte_valid_until < CURRENT_DATE
  AND q.qte_expiry_action IS NULL
ORDER BY q.qte_valid_until ASC;
```

This surfaces every quote that has silently aged past its validity window with no recorded disposition. Each row is a follow-up action — renew, cancel, or log the outcome.

---

### Average Revisions Before Acceptance
*How long does it typically take to get to yes?*

```sql
SELECT
    c.cust_type,
    AVG(revision_counts.version_count) AS avg_revisions_to_acceptance
FROM (
    SELECT
        q.cust_id,
        COALESCE(q.qte_parent_id, q.qte_id) AS quote_group,
        COUNT(q.qte_id) AS version_count
    FROM quote q
    WHERE q.qte_id IN (SELECT qte_id FROM "order")
    GROUP BY q.cust_id, COALESCE(q.qte_parent_id, q.qte_id)
) revision_counts
JOIN customer c ON revision_counts.cust_id = c.cust_id
GROUP BY c.cust_type
ORDER BY avg_revisions_to_acceptance DESC;
```

Customer types requiring more revisions signal either misaligned initial pricing, unclear scope, or a sales process that rewards negotiation. This query separates the signal from the noise.

---

### Quoted vs. Estimated Price Delta by Customer Tier
*Did the quote reflect what the estimate projected?*

```sql
SELECT
    c.cust_type,
    COUNT(*) AS quote_count,
    ROUND(AVG(q.qte_price - e.est_price), 2) AS avg_price_delta,
    ROUND(AVG((q.qte_price - e.est_price) / NULLIF(e.est_price, 0) * 100), 2) AS avg_pct_delta
FROM quote q
JOIN estimate e ON q.qte_est_id = e.est_id
JOIN customer c ON q.cust_id = c.cust_id
WHERE q.qte_version = 1
GROUP BY c.cust_type
ORDER BY avg_pct_delta ASC;
```

A negative `avg_price_delta` means quotes are going out below estimate — margin is being given away at the quote stage. Filtering to `qte_version = 1` isolates the original offer before any negotiation revision.

---

### Conversion Rate by Approver
*Which approvers are sending out winning quotes?*

```sql
SELECT
    u.user_first_name || ' ' || u.user_last_name AS approver,
    COUNT(q.qte_id)                               AS quotes_approved,
    COUNT(o.ord_id)                               AS quotes_converted,
    ROUND(
        COUNT(o.ord_id)::decimal / NULLIF(COUNT(q.qte_id), 0) * 100, 1
    )                                             AS conversion_rate_pct
FROM quote q
JOIN "user" u ON q.qte_approved_by = u.user_id
LEFT JOIN "order" o ON q.qte_id = o.qte_id
WHERE q.qte_approved_by IS NOT NULL
GROUP BY u.user_id, u.user_first_name, u.user_last_name
ORDER BY conversion_rate_pct DESC;
```

Conversion rate by approver reveals pricing culture: approvers who consistently approve aggressive discounts may show high conversion rates but poor margin outcomes. Pair this query with a margin analysis for the complete picture.

---

### Days from Quote Sent to Customer Response by Customer Tier
*How long do different customer types take to decide?*

```sql
SELECT
    c.cust_type,
    COUNT(*)                                                        AS responded_quotes,
    ROUND(AVG(q.qte_response_date - q.qte_sent_date), 1)          AS avg_days_to_response,
    MIN(q.qte_response_date - q.qte_sent_date)                     AS fastest_response,
    MAX(q.qte_response_date - q.qte_sent_date)                     AS slowest_response
FROM quote q
JOIN customer c ON q.cust_id = c.cust_id
WHERE q.qte_sent_date IS NOT NULL
  AND q.qte_response_date IS NOT NULL
GROUP BY c.cust_type
ORDER BY avg_days_to_response ASC;
```

Response time by customer tier informs follow-up cadence. If Reseller accounts typically respond in 3 days but Direct accounts take 12, the follow-up playbook should reflect that difference.

---

## Reflection

1. In your current process, how many versions does a typical quote go through before it is accepted or rejected? Is that number tracked anywhere today?

2. Think about the last time a quote went out the door and the customer came back with a counteroffer. What changed? Was that change captured anywhere in your data — or did it live only in an email thread?

3. Who in your organization has the authority to approve a quote? Is there a formal threshold — price, margin, delivery timeline — that triggers a review, or is the process informal? What would a structured approval record tell you that you cannot see today?

4. Consider the difference between the quote document your customer receives and the quote record in your system. What information does the document contain that the record does not — and vice versa? What belongs in the data that should never appear on the customer-facing artifact?

5. How many quotes in your current pipeline have passed their stated validity date without a recorded outcome? What would it mean for your pipeline accuracy if you could answer that question with a single query?

6. Think about a change that happened after a customer accepted a quote — a price correction, a date push, a quantity change. Was that handled as a new quote version, an informal email, or something else? Now that you understand the boundary between revisions and adjustments, where would that change belong in this schema?

---

**[← Chapter 3: Estimating with Confidence](03-estimating-with-confidence.md)** | **[Next Chapter → Chapter 5: Managing the Order](05-managing-the-order.md)**
