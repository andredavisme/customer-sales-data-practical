[← Table of Contents](TOC.md)

# Chapter 1: Knowing Your Customer

**Tier I → II** | *Contact data, customer segmentation, account hierarchy*

---

## Business Context

The Tier I `customer` table gives you four things: an ID, a type, a name, and a branch. That is enough to count customers, link them to transactions, and answer basic branch-level questions. It is not enough to actually *know* them.

Consider what happens when a delivery goes wrong. You need to call someone. Who? The `customer` table has no phone number, no email, no name of the person who placed the order. You know the company and the branch. You do not know the contact.

Or consider a quarterly business review. Your VP asks which customer segments are driving the most revenue. You have `cust_type`, but it was entered inconsistently — some records say "Direct," others say "direct client," others are blank. The field exists, but the data is not usable.

This is the pattern that Tier II addresses: the foundation is in place, but the real world demands more precision, more structure, and more people.

---

## The Data Gap

With only the Tier I `customer` table, here are the questions you *cannot* reliably answer:

- Who is the primary contact at this account?
- Who should receive the quote? Who approves the order?
- How many distinct branches are associated with a customer — and are they all being served consistently?
- Is this customer a subsidiary of a larger parent account we also serve?
- What industry is this customer in, and how does that affect how we serve them?

A note on branches: `cust_branch` in Tier I does allow you to ask *"how many branches are associated with a customer name?"* — but only as reliably as that field has been populated and standardized. It is a starting point, not a structure. Tier II formalizes the relationship between branches and parent accounts so the answer is authoritative rather than approximate.

A note on dates: customer initiation and last activity dates do not need to be stored directly on the customer record. No activity — request, order, delivery — can exist without a customer. The dates of a customer's first and most recent interactions are always derivable by querying their activity chain. Storing them redundantly on the customer record introduces maintenance burden without adding information. Each table in the model carries its own date-driven records; the customer record carries identity.

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

## Tier II Schema Updates

### Updated: `customer` Table

New attributes added in Tier II:

| Tier | Column Name | Attribute Name | Notes |
|------|-------------|---------------|-------|
| II | `parent_cust_id` | Parent Customer ID | Self-referencing FK → `customer.cust_id`; null for top-level accounts |
| II | `cust_industry` | Customer Industry | Standardized industry classification (e.g., Manufacturing, Retail, Healthcare) |
| II | `cust_tier` | Customer Tier | Internal strategic value classification (e.g., 1, 2, 3 or Platinum, Gold, Silver) |

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
WHERE parent_cust_id IS NULL  -- count parent accounts only to avoid double-counting
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

### When did a customer first do business with us, and when was their last order?

```sql
SELECT
  c.cust_id,
  c.cust_name,
  MIN(o.ord_exp_date) AS first_order_date,
  MAX(o.ord_exp_date) AS last_order_date
FROM customer c
JOIN "order" o ON c.cust_id = o.cust_id
GROUP BY c.cust_id, c.cust_name
ORDER BY last_order_date ASC;
```

This query illustrates the principle established in the Data Gap section: customer lifecycle dates are not stored on the customer record — they are derived from the activity chain. The `order` table, linked by `cust_id`, carries the dates. The customer record carries the identity.

---

## Reflection

1. Look at your own customer records. How many have a branch structure that your current system captures inconsistently? What questions does that prevent you from answering with confidence?

2. How are contacts currently stored in your organization? Are they in the same table as accounts, in a separate CRM, in someone's email client? What would it take to normalize them into a structure like the one above?

3. Choose three customer segments that would be meaningful to your business. What data would you need to populate them consistently? Who would own that data?

4. Pick any customer in your system and try to answer: when did they first do business with you, and when was their last transaction? Where did you have to look to answer that? Could it be answered with a single query against your current data?

---

**[← Introduction: The Customer's Data Journey](00-introduction.md)** | **[Next Chapter → Chapter 2: Capturing the Request](02-capturing-the-request.md)**
