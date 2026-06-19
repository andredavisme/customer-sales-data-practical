[← Table of Contents](TOC.md)

# Chapter 8: The Customer's Voice

**Tier III** | *Response scoring, NPS integration, feedback loops*

---

## Business Context

Every chapter in this textbook has been building toward this one.

The request captured what the customer needed. The estimate described what it would take. The quote made the promise. The order confirmed the agreement. The delivery either kept the promise or broke it. The adjustment recorded what was done about it. The response record is the customer's verdict on all of it.

It is the only record in the schema that comes entirely from outside your organization. Every other record was created by someone on your team — a sales rep, an estimator, a logistics coordinator. The response is created by the customer. That makes it the most honest signal in your data, and often the most underused.

In most organizations, customer feedback exists in fragments: an email thread, a comment in a CRM note, a score in a survey platform that never gets linked to a specific transaction. It is collected inconsistently, stored disconnected from the order it refers to, and analyzed — if at all — as an aggregate statistic stripped of operational context.

The schema approach changes that. When a response record is linked to a specific delivery, order, and customer, the feedback is no longer just a number — it is evidence about a specific transaction. A low satisfaction score linked to a delivery that was twelve days late, with a price adjustment applied two weeks earlier, tells a story that an aggregate NPS score never could.

---

## The Data Gap

The Tier I `response` table has one data field: `cust_response`. A single free-text column.

With only Tier I data, you cannot answer:

- What was the customer's satisfaction score for this specific transaction?
- Did the response come after delivery, after an adjustment, or unprompted?
- How long after the delivery did the customer respond?
- Was the feedback positive, neutral, or negative — and by how much?
- What was the customer's Net Promoter Score, and which transaction triggered it?
- Which response category appears most frequently following a late delivery?
- Are customers who received an adjustment more or less likely to respond positively?
- Which customers have gone silent — delivered to, no response recorded?

The free-text field captures narrative. It cannot support any of these questions as structured queries. Tier III structures the response record so that the narrative is preserved but the operational signals are extracted into queryable fields.

---

## Structuring Feedback as Data

The core challenge with customer feedback is that it arrives in qualitative form — sentences, scores, ratings, tones — and most of it resists easy categorization. The schema's job is not to reduce that richness to a number. It is to capture enough structured signal alongside the narrative that the data becomes queryable without losing its human context.

This requires separating three things that are often conflated:

1. **The score** — a numeric or categorical rating, comparable across records
2. **The category** — what aspect of the experience the feedback addresses (delivery, pricing, quality, communication)
3. **The sentiment** — the overall tone, independent of the specific score
4. **The narrative** — the free-text content that explains the score and category

The Tier I `cust_response` field holds the narrative. Tier III adds the score, the category, and the sentiment as structured fields alongside it.

---

## Tier III Schema Additions: Response

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|----------------|-------|
| III | `resp_date` | Response Date | When the response was received or recorded |
| III | `resp_type` | Response Type | Controlled vocabulary: Survey, Direct-Contact, Portal, Review, NPS |
| III | `resp_score` | Satisfaction Score | Numeric rating on a consistent scale (e.g., 1–5 or 1–10); NULL if not scored |
| III | `resp_score_scale` | Score Scale | Documents the scale used: e.g., `1-5`, `1-10`, `NPS` — required when `resp_score` is populated |
| III | `resp_category` | Feedback Category | Controlled vocabulary: Delivery, Pricing, Quality, Communication, Process, Overall |
| III | `resp_sentiment` | Sentiment | Controlled vocabulary: Positive, Neutral, Negative — derived or manually coded |
| III | `resp_nps` | NPS Score | Integer -100 to 100, or raw 0–10 promoter score; NULL if NPS was not collected |
| III | `resp_followup_required` | Follow-Up Required | Boolean: whether this response warrants a follow-up action |
| III | `resp_followup_owner` | Follow-Up Owner | FK → `user.user_id`; who is responsible for the follow-up action |
| III | `resp_resolved` | Resolved | Boolean: whether any flagged follow-up has been completed |

### `resp_date`: Timing the Response

When a response arrives matters as much as what it says. A negative response logged two days after delivery is a different operational signal than one logged six weeks later. The gap between `del_date` and `resp_date` is the customer's reaction window — and patterns in that window reveal urgency, severity, and engagement.

Customers who respond immediately to negative experiences are more likely to churn without intervention. Customers who respond weeks later, positively, often represent the most loyal segment. Neither insight is visible without `resp_date`.

### `resp_type`: How It Arrived

The channel through which feedback arrives shapes both its reliability and its context. A survey response is structured and prompted. A direct contact response is unsolicited and typically more emotionally charged. A portal review is public and carries reputational weight beyond the individual transaction.

Knowing the type allows you to weight responses appropriately in aggregate analysis and to manage follow-up by channel — a public review requires a different response than a private survey.

### `resp_score` and `resp_score_scale`: Consistent Measurement

A satisfaction score without its scale is meaningless for comparison. A score of 7 on a 1–10 scale is strong. A score of 7 on a 1–100 scale is alarming. `resp_score_scale` is mandatory when `resp_score` is populated — it is the metadata that makes the number interpretable across time, teams, and survey platforms.

Organizations that use multiple survey tools, or that have changed scoring systems over time, frequently find their historical response data incomparable because the scale was never recorded. This field prevents that problem from the start.

### `resp_nps`: Net Promoter Score as a Linked Record

NPS is the most widely used customer loyalty metric in business. The standard question — *"How likely are you to recommend us to a colleague or friend?"* scored 0–10 — produces a Promoter (9–10), Passive (7–8), or Detractor (0–6) classification.

Most organizations collect NPS through a standalone survey platform and never link the score to the transaction that generated it. The result is an aggregate number — *"Our NPS this quarter was 42"* — with no operational context.

When `resp_nps` is stored on the `response` record, linked to a specific `del_id` and `ord_id`, the question changes from *"what is our NPS?"* to *"what drives our NPS?"* A detractor response linked to a late delivery with an unresolved adjustment is a pattern. A promoter response linked to an on-time delivery on a complex multi-shipment order is a different pattern. Both are invisible without the transactional link.

### `resp_followup_required` and `resp_followup_owner`: Closing the Loop

A response record with no follow-up mechanism is a data collection exercise, not a feedback loop. `resp_followup_required` flags responses that warrant action. `resp_followup_owner` assigns accountability. `resp_resolved` tracks closure.

Together, these three fields transform the response table from a passive log into an active queue — the same pattern established for adjustments in Chapter 7. A query filtering for `resp_followup_required = TRUE` and `resp_resolved = FALSE` is the customer follow-up list for the day.

---

## NPS Integration: Linking Scores to Transactions

The practical mechanics of NPS integration deserve a brief discussion, because the schema supports it but does not enforce a specific collection process.

NPS surveys are typically sent at a defined trigger point — most commonly after delivery, after the resolution of an adjustment, or at a periodic relationship interval (quarterly, annually). The trigger point should be captured in `resp_type` and the timing should be recoverable from `resp_date` relative to `del_date`.

Two common patterns:

**Transactional NPS** — sent after each delivery. The response record is created at the time of delivery and updated when the survey response arrives. `resp_nps` is populated then. This links the score directly to the transaction.

**Relationship NPS** — sent periodically, not tied to a specific transaction. In this case, the response record is linked at the customer level (`cust_id`) with `del_id` and `ord_id` left NULL. The score reflects the overall relationship state at a point in time rather than a specific event.

Both patterns are supported by the schema. The distinction matters for analysis: transactional NPS tells you what drives scores up or down at the event level; relationship NPS tells you the cumulative health of the customer relationship over time.

---

## The Feedback Loop: How Response Data Feeds Back

The response table is not the end of the journey — it is the beginning of the next one.

A customer who scores a 4 out of 10 and flags a delivery issue is the source of a new request for intervention. A detractor who received two adjustments in the past quarter is a churn risk signal. A promoter who consistently scores 9–10 across multiple orders is a candidate for a reference conversation or a case study.

The schema supports these feedback loops through the same foreign key chain that runs through every other table. The response record links back to the delivery, the order, the quote, the estimate, the request, and the customer. That means any query that starts with a response score can traverse the entire journey to find its cause.

This is the data lineage principle introduced in the Introduction, fully realized: every outcome can be traced back to its origin.

---

## Analytical Application

### Average Satisfaction Score by Delivery Performance
*Do customers who got what was promised actually score higher?*

```sql
SELECT
    CASE
        WHEN d.del_date <= o.ord_promised_date THEN 'On Time'
        WHEN d.del_date <= o.ord_promised_date + 3 THEN '1-3 Days Late'
        WHEN d.del_date <= o.ord_promised_date + 7 THEN '4-7 Days Late'
        ELSE 'More Than 7 Days Late'
    END                                          AS delivery_bucket,
    COUNT(r.resp_id)                             AS response_count,
    ROUND(AVG(r.resp_score), 2)                  AS avg_satisfaction,
    ROUND(AVG(r.resp_nps), 2)                    AS avg_nps
FROM response r
JOIN delivery d ON r.del_id  = d.del_id
JOIN "order"  o ON r.ord_id  = o.ord_id
WHERE r.resp_score      IS NOT NULL
  AND r.resp_score_scale = '1-10'
  AND o.ord_promised_date IS NOT NULL
GROUP BY delivery_bucket
ORDER BY avg_satisfaction DESC;
```

This query answers the foundational question of delivery analytics: does on-time performance actually move customer satisfaction? If scores are flat across delivery buckets, the problem is elsewhere — pricing, quality, or communication. If scores drop sharply with lateness, the investment in on-time delivery is directly justified by customer outcome data.

---

### NPS by Customer Segment and Quarter
*Where is loyalty growing — and where is it eroding?*

```sql
SELECT
    DATE_TRUNC('quarter', r.resp_date)           AS quarter,
    c.cust_type,
    COUNT(r.resp_id)                             AS responses,
    ROUND(AVG(r.resp_nps), 1)                    AS avg_nps_score,
    COUNT(CASE WHEN r.resp_nps >= 9 THEN 1 END)  AS promoters,
    COUNT(CASE WHEN r.resp_nps BETWEEN 7 AND 8 THEN 1 END) AS passives,
    COUNT(CASE WHEN r.resp_nps <= 6 THEN 1 END)  AS detractors,
    ROUND(
        (COUNT(CASE WHEN r.resp_nps >= 9 THEN 1 END)::decimal
        - COUNT(CASE WHEN r.resp_nps <= 6 THEN 1 END)::decimal)
        / NULLIF(COUNT(r.resp_id), 0) * 100, 1
    )                                            AS nps_score
FROM response r
JOIN customer c ON r.cust_id = c.cust_id
WHERE r.resp_nps IS NOT NULL
GROUP BY DATE_TRUNC('quarter', r.resp_date), c.cust_type
ORDER BY quarter ASC, c.cust_type ASC;
```

NPS calculated quarterly by customer segment shows whether loyalty is moving directionally, and whether it moves differently for Direct vs. Reseller vs. Internal accounts. A segment where the detractor share is growing quarter-over-quarter is a retention risk — visible here before it shows up in churn data.

---

### Adjustment Impact on Response Scores
*Do customers who received an adjustment score differently than those who did not?*

```sql
SELECT
    CASE
        WHEN adj_counts.adj_count IS NULL THEN 'No Adjustments'
        WHEN adj_counts.adj_count = 1    THEN '1 Adjustment'
        ELSE '2+ Adjustments'
    END                                         AS adjustment_group,
    COUNT(r.resp_id)                            AS response_count,
    ROUND(AVG(r.resp_score), 2)                 AS avg_satisfaction,
    ROUND(AVG(r.resp_nps),   2)                 AS avg_nps,
    COUNT(CASE WHEN r.resp_sentiment = 'Negative' THEN 1 END) AS negative_responses
FROM response r
LEFT JOIN (
    SELECT ord_id, COUNT(*) AS adj_count
    FROM adjustment
    WHERE adj_status = 'Applied'
    GROUP BY ord_id
) adj_counts ON r.ord_id = adj_counts.ord_id
WHERE r.resp_score      IS NOT NULL
  AND r.resp_score_scale = '1-10'
GROUP BY adjustment_group
ORDER BY avg_satisfaction DESC;
```

The expected result is that orders with more adjustments score lower. What makes this query interesting is the exception: orders where adjustments were handled well may score *higher* than baseline, because a well-resolved problem can generate more loyalty than a transaction with no problems. That recovery effect — if it exists in your data — is one of the most actionable insights in customer experience management.

---

### Open Follow-Up Queue
*Which customers need a response today?*

```sql
SELECT
    r.resp_id,
    c.cust_name,
    r.resp_date,
    r.resp_type,
    r.resp_score,
    r.resp_nps,
    r.resp_sentiment,
    r.cust_response                                      AS feedback_text,
    CURRENT_DATE - r.resp_date                           AS days_since_response,
    u.user_first_name || ' ' || u.user_last_name         AS followup_owner
FROM response r
JOIN customer  c ON r.cust_id            = c.cust_id
LEFT JOIN "user" u ON r.resp_followup_owner = u.user_id
WHERE r.resp_followup_required = TRUE
  AND r.resp_resolved           = FALSE
ORDER BY r.resp_date ASC;
```

The aging column — `days_since_response` — is what makes this a queue rather than a list. Responses that have been sitting without action for seven or more days are not just an operational gap; they are a signal to the customer that their feedback was not heard. This query is the instrument that prevents that.

---

### Customers with No Response Recorded
*Who has gone silent?*

```sql
SELECT
    c.cust_id,
    c.cust_name,
    c.cust_type,
    MAX(d.del_date)                                      AS last_delivery_date,
    CURRENT_DATE - MAX(d.del_date)                       AS days_since_last_delivery,
    COUNT(DISTINCT o.ord_id)                             AS total_orders
FROM customer c
JOIN "order"  o ON c.cust_id = o.cust_id
JOIN delivery d ON o.ord_id  = d.ord_id
LEFT JOIN response r ON r.cust_id = c.cust_id
WHERE r.resp_id IS NULL
GROUP BY c.cust_id, c.cust_name, c.cust_type
HAVING MAX(d.del_date) >= CURRENT_DATE - INTERVAL '180 days'
ORDER BY days_since_last_delivery ASC;
```

Silence is a signal. Customers who have been delivered to within the past six months but have never submitted a response — no survey, no direct contact, no NPS — are either disengaged, unfamiliar with your feedback channels, or passively dissatisfied. This query surfaces them before the silence becomes churn. Prioritize by `total_orders` to focus outreach on high-value accounts first.

---

## Closing the Loop: Response Data Into the Next Journey

The response record does not just close the current journey — it informs the next one. Two patterns are worth building as standard practice:

**Detractor follow-up as a new request.** When `resp_followup_required = TRUE` on a negative response, the follow-up action is structurally identical to a new customer request: a customer has a need, and your organization needs to respond. In mature implementations, flagged responses can automatically seed a new `request` record, linking the corrective action back to the original transaction chain.

**Promoter engagement.** Customers who consistently score 9–10 across multiple transactions are your reference base. A query joining response scores to customer tenure (`cust_since`), order count, and revenue is the input to a proactive relationship management program — not a reactive one.

Both of these close the loop between the last step in the journey (response) and the first (request), making the schema not a linear chain but a cycle.

---

## Reflection

1. How does your organization currently collect customer feedback after a delivery? Is that feedback linked to the specific transaction it refers to, or is it stored separately from your order data? What is lost when the two are not connected?

2. Think about the last negative piece of feedback your team received. Could you trace it back to a specific delivery date, a quote version, an adjustment record? How many steps in the data chain would you have to reconstruct manually to understand the full context?

3. Consider the `resp_score_scale` field. Has your organization ever changed its survey platform or scoring system? If so, how do your pre- and post-change scores compare? What would it take to make them comparable?

4. The query in this chapter shows that customers who received well-handled adjustments may score *higher* than baseline. Does that align with what you observe in your customer relationships? What would you need to measure to confirm or refute it in your own data?

5. Think about the customers in your portfolio who have never submitted feedback. Are they your most satisfied customers — or your most disengaged? What is your current strategy for distinguishing between the two, and how would the silent customer query change your outreach priorities?

---

**[← Chapter 7: When Things Change](07-when-things-change.md)** | **[Next Chapter → Chapter 9: Measuring Performance](09-measuring-performance.md)**
