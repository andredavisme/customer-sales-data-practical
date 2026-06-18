[← Table of Contents](TOC.md)

# Chapter 1: Knowing Your Customer

**Tier I → II** | *Contact data, customer segmentation, account hierarchy*

---

## Business Context

The Tier I `customer` table gives you four things: an ID, a type, a name, and a branch. That is enough to count customers and link them to transactions. It is not enough to actually *know* them.

Consider what happens when a delivery goes wrong. You need to call someone. Who? The `customer` table has no phone number, no email, no name of the person who placed the order. You know the company. You do not know the contact.

Or consider a quarterly business review. Your VP asks which customer segments are driving the most revenue. You have `cust_type`, but it was entered inconsistently — some records say "Direct," others say "direct client," others are blank. The field exists, but the data is not usable.

This is the pattern that Tier II addresses: the foundation is in place, but the real world demands more precision, more structure, and more people.

---

## The Data Gap

With only the Tier I `customer` table, here are the questions you *cannot* answer:

- Who is the primary contact at this account?
- Who should receive the quote? Who approves the order?
- Does this customer have multiple locations, each with their own purchasing behavior?
- Is this a subsidiary of a larger parent account we also serve?
- What industry is this customer in, and how does that affect how we serve them?
- When did we first acquire this customer, and how long have they been with us?

None of these require exotic data. They require a more complete customer record and a dedicated contact structure.

---

## Contacts: The People Behind the Account

A customer is an organization. A contact is a person. These are fundamentally different records and they should never be collapsed into one table.

The separation matters for several reasons:

- **One customer has many contacts.** The person who places orders is rarely the same person who approves invoices, receives deliveries, or escalates complaints.
- **Contacts change; customers don't.** Personnel turns over. When a contact leaves, you update their record — you do not delete the customer.
- **Contact roles define workflow.** Knowing that a contact is a "Billing" contact versus an "Operations" contact versus a "Decision Maker" routes communications correctly and makes your sales process data-driven.

A Tier II `contact` table captures the human layer of the customer relationship. It links to the `customer` table via `cust_id` and introduces its own primary key `cont_id`.

---

## Customer Segmentation

Segmentation is how you stop treating all customers identically and start analyzing them as groups with distinct behaviors, needs, and value.

The Tier I `cust_type` field is a start, but a single field cannot carry the full weight of segmentation. Tier II expands this with two additional attributes:

- **`cust_industry`** — What sector does this customer operate in? Industry segmentation unlocks comparisons like *"do manufacturing customers place larger orders than retail customers?"* or *"which industries have the highest adjustment rates?"*
- **`cust_tier`** — An internal classification of the customer's strategic value. Common tiers are Platinum, Gold, Silver, or numeric equivalents (1, 2, 3). This is distinct from type — a "Direct" customer can be Tier 1 or Tier 3 depending on revenue, longevity, and growth potential.

Segmentation data is only as good as the discipline used to populate and maintain it. A field that is 40% blank is not a segment — it is a guess. When you introduce these fields, define the allowed values, make them required, and assign an owner responsible for keeping them current.

---

## Account Hierarchy

Many of your customers are not standalone organizations. They are subsidiaries of parent companies, regional branches of national accounts, or franchisees of larger brands. If your data model does not reflect this, your analysis will be wrong in ways that are hard to detect.

Example: You serve four locations of the same regional grocery chain. Each location has its own `cust_id` because they have different shipping addresses and different buyers. But for the purposes of revenue reporting, contract negotiation, and relationship management, they are one account. If you analyze them separately, you understate the relationship. If you cannot connect them, you cannot negotiate at the parent level.

Tier II handles this with a self-referencing foreign key: **`parent_cust_id`**. When a customer record is a subsidiary or branch of another customer, `parent_cust_id` points to the parent's `cust_id`. Parent accounts have a null `parent_cust_id`.

This single field unlocks:
- Rolled-up revenue reporting by parent account
- Identifying your true top accounts (not just the loudest location)
- Multi-site contract management
- Recognizing when a "new" customer is actually a new branch of an existing relationship

---

## Customer Lifecycle Dates

Two timestamps belong on every customer record and are conspicuously absent from Tier I:

- **`cust_since`** — The date this customer was first acquired. This is the anchor for tenure analysis, cohort reporting, and churn modeling.
- **`cust_last_activity`** — The date of the most recent transaction or interaction. This is the single most important signal for identifying at-risk customers before they leave quietly.

These fields are not complex. They require only that someone — or some automated process — populates them consistently. But their absence is responsible for an enormous share of "we didn't see it coming" customer churn.

---

## Tier II Schema Updates

### Updated: `customer` Table

New attributes added in Tier II:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `parent_cust_id` | Parent Customer ID | Self-referencing FK → `customer.cust_id`; null for top-level accounts |
| II | `cust_industry` | Customer Industry | Standardized industry classification (e.g., Manufacturing, Retail, Healthcare) |
| II | `cust_tier` | Customer Tier | Internal strategic value classification (e.g., 1, 2, 3 or Platinum, Gold, Silver) |
| II | `cust_since` | Customer Since | Date of first acquisition |
| II | `cust_last_activity` | Last Activity Date | Date of most recent transaction or interaction |

### New Table: `contact`

Captures the individual people associated with a customer account.

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `cont_id` | Contact ID | Primary key |
| II | `cust_id` | Customer ID | Foreign key → `customer` |
| II | `cont_first_name` | First Name | |
| II | `cont_last_name` | Last Name | |
| II | `cont_title` | Title | Job title or role at the customer organization |
| II | `cont_role` | Contact Role | Functional classification: e.g., Buyer, Billing, Operations, Decision Maker |
| II | `cont_email` | Email Address | Primary contact email |
| II | `cont_phone` | Phone Number | Primary contact phone |
| II | `cont_primary` | Primary Contact Flag | Boolean — true if this is the default contact for the account |
| II | `cont_active` | Active Flag | Boolean — false if this contact has left the organization |

---

## Analytical Application

With the Tier II `customer` and `contact` tables in place, you can now answer a new class of questions.

### How many active customers do we have by industry?

```sql
SELECT
  cust_industry,
  COUNT(cust_id) AS customer_count
FROM customer
WHERE cust_last_activity >= CURRENT_DATE - INTERVAL '12 months'
  AND parent_cust_id IS NULL  -- count parent accounts only to avoid double-counting
GROUP BY cust_industry
ORDER BY customer_count DESC;
```

### Who are our top accounts by total order value, rolled up to the parent?

```sql
SELECT
  COALESCE(c.parent_cust_id, c.cust_id) AS top_account_id,
  COALESCE(p.cust_name, c.cust_name) AS account_name,
  SUM(o.ord_price) AS total_order_value
FROM "order" o
JOIN customer c ON o.cust_id = c.cust_id
LEFT JOIN customer p ON c.parent_cust_id = p.cust_id
GROUP BY top_account_id, account_name
ORDER BY total_order_value DESC
LIMIT 10;
```

### Which accounts have no primary contact on record?

```sql
SELECT
  c.cust_id,
  c.cust_name
FROM customer c
LEFT JOIN contact ct
  ON c.cust_id = ct.cust_id AND ct.cont_primary = TRUE
WHERE ct.cont_id IS NULL;
```

This last query is a data quality check as much as an analytical one. Accounts with no primary contact are a liability — they are the ones you cannot reach when something goes wrong.

---

## Reflection

1. Look at your own customer records. How many have a `parent_cust_id` equivalent — a relationship to another account that your current system does not capture? What does that cost you in reporting accuracy?

2. How are contacts currently stored in your organization? Are they in the same table as accounts, in a separate CRM, in someone's email client? What would it take to normalize them into a structure like the one above?

3. Choose three customer segments that would be meaningful to your business. What data would you need to populate them consistently? Who would own that data?

4. When was the last time a customer left without you seeing it coming? Would a `cust_last_activity` field, consistently maintained, have given you a signal earlier?

---

**[← Introduction: The Customer's Data Journey](00-introduction.md)** | **[Next Chapter → Chapter 2: Capturing the Request](02-capturing-the-request.md)**
