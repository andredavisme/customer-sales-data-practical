# Chapter 4: Quoting for Clarity

## Business Context

The estimate was an internal document. The quote is the first artifact the customer sees.

That distinction changes everything. An estimate carries internal cost and margin logic — it lives inside your organization. A quote is a commercial commitment: it states a price, a delivery date, and an implied promise. Once sent, it creates expectations. Once accepted, it becomes the contractual foundation of the order.

Because of this, quotes are different from every other record in the journey. They are revised. They expire. They require approval. And they are evaluated not just by whether they were accepted, but by *when* — and by *whom*.

The Tier I quote table captured the basics: price, delivery date, and a link to the estimate. That was sufficient for tracking what was agreed. It is not sufficient for understanding *how* you got there.

---

## The Data Gap

With the current Tier I quote schema, six questions remain unanswerable:

1. **How many revisions did this quote go through before acceptance?** — There is no version history; each update overwrites the previous record.
2. **What changed between quote versions?** — Without versioning, there is no baseline to compare against.
3. **Who approved this quote before it was sent?** — Approval is untracked; any quote can be sent without authorization.
4. **How many active quotes have passed their validity date?** — There is no expiry field or action recorded.
5. **How long does it typically take customers to respond to a quote?** — Sent date and response date are not captured.
6. **Which approver has the highest conversion rate?** — Approver data does not exist.

Each of these gaps is operationally expensive. Unanswered revision history obscures negotiation patterns. Missing expiry tracking leads to outdated quotes being referenced in deals. No approval record means no audit trail.

---

## Quote Versioning

### The Revision Problem

In practice, quotes are rarely accepted on the first draft. Pricing gets negotiated. Delivery dates shift. Line items get added or removed. In a Tier I schema where each quote is a single mutable record, every revision destroys the history of what came before it.

The solution is a **self-referencing parent key** — the same pattern introduced for account hierarchy in Chapter 1.

A new column `quot_parent_id` references `quot_id` in the same table. The original quote has no parent (`NULL`). Each revision points back to the quote it superseded.

A companion integer column `quot_version` makes the sequence explicit: version 1 is the original, version 2 is the first revision, and so on. The active quote is always the highest version number within a `quot_parent_id` group.

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| quot_parent_id | Parent Quote ID | FK → quote.quot_id | II | NULL on original; points to prior version on revisions |
| quot_version | Quote Version | — | II | Integer; 1 = original, increment per revision |

**Why this matters:** When a deal closes, you can now trace the full revision history — how many versions it took, what changed at each step, and whether the final price was above or below the initial offer. This is the negotiation audit trail that every sales manager wants but almost no one has captured cleanly.

---

## Approval Workflows

### Authorization Before Delivery

Not every quote should go out the door without review. Discounts beyond a threshold, unusually long payment terms, or delivery commitments that stretch capacity all warrant a second set of eyes. Approval workflows formalize this.

Two paired fields capture the complete approval record:

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| quot_prepared_by | Prepared By | FK → user.user_id | II | Who built the quote |
| quot_approved_by | Approved By | FK → user.user_id | II | Who authorized it for delivery; NULL if not yet approved |
| quot_approved_date | Approval Date | — | II | Date approval was granted; NULL if pending |

Both approval fields reference the `user` table introduced in Chapter 3 — the same table that anchors `req_owner` and `est_prepared_by`. The user table is doing its job: consolidating identity and role across all records in the journey.

**The diagnostic signal:** A quote with `quot_approved_by` populated but `quot_approved_date` as NULL is a data quality flag — the record suggests someone approved it but no date was logged. A query targeting this pattern surfaces either a process gap (approvals happening verbally) or a data entry issue (the date field being skipped).

**The analytical payoff:** Once both fields are consistently populated, you can compare conversion rates by approver. If quotes approved by one manager convert at 60% and quotes approved by another convert at 35%, that is a coaching signal — or a pricing strategy signal — worth investigating.

---

## Quote Expiry

### The Silent Aging Problem

Quotes have a shelf life. Costs change. Supplier pricing fluctuates. Capacity fills. A quote issued six months ago may no longer reflect what it would cost to fulfill today — but without an expiry mechanism, nothing in the data flags that it has gone stale.

Two fields address this:

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| quot_valid_until | Valid Until Date | — | II | The date the quote is no longer actionable without reissue |
| quot_expiry_action | Expiry Action | — | II | Structured field: Renewed, Cancelled, Expired-No-Action, Superseded |

`quot_valid_until` is the operational anchor. A daily query filtering for quotes where `quot_valid_until < CURRENT_DATE` and status is still open produces the action list for the day.

`quot_expiry_action` is the disposition record. Rather than leaving expired quotes to accumulate ambiguously in the system, this field captures what actually happened: was the quote renewed with updated pricing? Cancelled by the customer? Did it simply expire with no follow-up? Or was it superseded by a revision?

**Why a structured field matters here:** Free-text notes fields decay into illegibility over time. A structured `quot_expiry_action` with a controlled vocabulary allows you to query — "how many quotes expired with no action in Q2?" — and act on the answer.

---

## Linking to Estimates

The quote does not exist in isolation. It is the externalization of the internal estimate — and the relationship between them is worth tracking explicitly.

A direct foreign key `quot_est_id` links the quote to the estimate it was built from. This enables the **price integrity check**: did the quote price accurately reflect the estimated cost and margin?

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| quot_est_id | Estimate ID | FK → estimate.est_id | II | The estimate this quote was derived from |

With this link in place, a query comparing `qte_price` to `est_price` across all quotes will surface the delta — how often quotes went out at prices above or below the estimate, and by how much. Patterns of systematic underquoting relative to estimates are a margin erosion signal that is invisible without this join.

---

## Quote Lines

Just as the estimate introduced `estimate_line` to capture item-level detail, the quote introduces a parallel `quote_line` table. The difference is audience: estimate lines hold internal cost logic; quote lines hold the customer-facing representation of the same items.

**quote_line table:**

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| qln_id | Quote Line ID | PK | II | Primary key |
| quot_id | Quote ID | FK → quote.quot_id | II | Parent quote |
| eln_id | Estimate Line ID | FK → estimate_line.eln_id | II | The estimate line this quote line corresponds to |
| qln_description | Line Description | — | II | Customer-facing description of the item or service |
| qln_quantity | Quantity | — | II | Quoted quantity |
| qln_unit_price | Unit Price | — | II | Price per unit as presented to the customer |
| qln_line_total | Line Total | — | II | Calculated: qln_quantity × qln_unit_price |

The link to `eln_id` is important — it connects each quote line back to the estimate line it was priced from. This allows a line-level price-to-cost comparison, not just a header-level one.

---

## Tier II Schema Additions: Quote

The complete set of Tier II additions to the `quote` table:

| Column Name | Attribute Name | Key Type | Tier | Notes |
|---|---|---|---|---|
| quot_est_id | Estimate ID | FK → estimate.est_id | II | Estimate this quote was derived from |
| quot_parent_id | Parent Quote ID | FK → quote.quot_id | II | NULL on original; prior version on revisions |
| quot_version | Quote Version | — | II | Integer; 1 = original |
| quot_prepared_by | Prepared By | FK → user.user_id | II | Who built the quote |
| quot_approved_by | Approved By | FK → user.user_id | II | Who authorized it |
| quot_approved_date | Approval Date | — | II | Date of approval |
| quot_sent_date | Sent Date | — | II | Date delivered to the customer |
| quot_response_date | Response Date | — | II | Date customer replied (accepted, rejected, or countered) |
| quot_valid_until | Valid Until Date | — | II | Expiry date |
| quot_expiry_action | Expiry Action | — | II | Renewed, Cancelled, Expired-No-Action, Superseded |

---

## Analytical Application

### SQL Example 1: Expired Quotes Without a Closed Status
*The daily operations query — what needs attention today.*

```sql
SELECT
    q.quot_id,
    q.quot_version,
    c.cust_name,
    q.qte_price,
    q.quot_valid_until,
    u.name AS prepared_by
FROM quote q
JOIN customer c ON q.cust_id = c.cust_id
JOIN user u ON q.quot_prepared_by = u.user_id
WHERE q.quot_valid_until < CURRENT_DATE
  AND q.quot_expiry_action IS NULL
ORDER BY q.quot_valid_until ASC;
```

This surfaces every quote that has silently aged past its validity window with no recorded disposition. Each row is a follow-up action — renew, cancel, or log the outcome.

---

### SQL Example 2: Average Revisions Before Acceptance
*How long does it typically take to get to yes?*

```sql
SELECT
    c.cust_type,
    AVG(revision_counts.version_count) AS avg_revisions_to_acceptance
FROM (
    SELECT
        q.cust_id,
        q.quot_parent_id,
        COUNT(q.quot_id) AS version_count
    FROM quote q
    WHERE q.quot_expiry_action = 'Accepted'
       OR q.quot_id IN (SELECT qte_id FROM "order")
    GROUP BY q.cust_id, COALESCE(q.quot_parent_id, q.quot_id)
) revision_counts
JOIN customer c ON revision_counts.cust_id = c.cust_id
GROUP BY c.cust_type
ORDER BY avg_revisions_to_acceptance DESC;
```

Customer types requiring more revisions signal either misaligned initial pricing, unclear scope, or a sales process that rewards negotiation. This query separates the signal from the noise.

---

### SQL Example 3: Quoted vs. Estimated Price Delta by Customer Tier
*Did the quote reflect what the estimate projected?*

```sql
SELECT
    c.cust_type,
    COUNT(*) AS quote_count,
    ROUND(AVG(q.qte_price - e.est_price), 2) AS avg_price_delta,
    ROUND(AVG((q.qte_price - e.est_price) / NULLIF(e.est_price, 0) * 100), 2) AS avg_pct_delta
FROM quote q
JOIN estimate e ON q.quot_est_id = e.est_id
JOIN customer c ON q.cust_id = c.cust_id
WHERE q.quot_version = 1
GROUP BY c.cust_type
ORDER BY avg_pct_delta ASC;
```

A negative `avg_price_delta` means quotes are going out below estimate — margin is being given away at the quote stage. Filtering to `quot_version = 1` isolates the original offer before any negotiation revision.

---

### SQL Example 4: Conversion Rate by Approver
*Which approvers are sending out winning quotes?*

```sql
SELECT
    u.name AS approver,
    COUNT(q.quot_id) AS quotes_approved,
    COUNT(o.ord_id) AS quotes_converted,
    ROUND(COUNT(o.ord_id)::decimal / NULLIF(COUNT(q.quot_id), 0) * 100, 1) AS conversion_rate_pct
FROM quote q
JOIN user u ON q.quot_approved_by = u.user_id
LEFT JOIN "order" o ON q.quot_id = o.qte_id
WHERE q.quot_approved_by IS NOT NULL
GROUP BY u.name
ORDER BY conversion_rate_pct DESC;
```

Conversion rate by approver reveals pricing culture: approvers who consistently approve aggressive discounts may show high conversion rates but poor margin outcomes. Pair this query with a margin analysis for the complete picture.

---

### SQL Example 5: Days from Quote Sent to Customer Response by Customer Tier
*How long do different customer types take to decide?*

```sql
SELECT
    c.cust_type,
    COUNT(*) AS responded_quotes,
    ROUND(AVG(q.quot_response_date - q.quot_sent_date), 1) AS avg_days_to_response,
    MIN(q.quot_response_date - q.quot_sent_date) AS fastest_response,
    MAX(q.quot_response_date - q.quot_sent_date) AS slowest_response
FROM quote q
JOIN customer c ON q.cust_id = c.cust_id
WHERE q.quot_sent_date IS NOT NULL
  AND q.quot_response_date IS NOT NULL
GROUP BY c.cust_type
ORDER BY avg_days_to_response ASC;
```

Response time by customer tier informs follow-up cadence. If Reseller accounts typically respond in 3 days but Direct accounts take 12, the follow-up playbook should differ accordingly.

---

## Reflection

1. In your current process, how many versions does a typical quote go through before it is accepted or rejected? Is that number tracked anywhere today?

2. Who has the authority to approve a quote in your organization? Is there a formal threshold (price, margin, delivery timeline) that triggers an approval requirement — or is it informal?

3. Think about a quote that expired without a clear outcome in the last 12 months. What actually happened to that deal? What would you need in your data to answer that question reliably?

4. If you could ask one question about your quoting process that you currently cannot answer with your data, what would it be? Describe the fields you would need to capture to answer it.

---

*Next: Chapter 5 — Managing the Order. The quote has been accepted. Now the operational reality begins: order lines, quantities, scheduling, and the first encounter with partial fulfillment.*
