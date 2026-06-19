[← Table of Contents](TOC.md)

# Customer Sales Data: A Practical Guide to Building and Using Sales Intelligence

**A textbook for service and product suppliers on organizing, understanding, and acting on customer data.**

---

## Preface

This textbook is designed for practitioners — the people who work inside sales operations, customer success, order management, and business intelligence teams. It does not assume you are a data scientist. It assumes you work with customers, handle transactions, and at some point have asked: *"Why can't I just get a straight answer from our data?"*

The answer to that question usually lies not in the tools, but in the foundation. Data that lacks structure, discipline, and a clear model of the customer journey will frustrate every analyst, every dashboard, and every business review it touches. This textbook builds that foundation — from a single customer record to a fully operational sales intelligence system.

Each chapter introduces new analytical needs and expands the data model to meet them. By the end, you will have a schema capable of supporting a modern CRM and the analytical vocabulary to use it confidently.

---

## Introduction: The Customer's Data Journey

### The Problem with Cluttered Data

When managing information about the services and products you offer, a strong understanding of the customer's journey from a data perspective is essential. On a clear path, the journey is easier than one cluttered with debris.

Debris comes in the form of redundant information, personal bias, and reckless KPI hunts. Communication gets lost and mistranslated. Teams build their own shadow spreadsheets. Reports contradict each other. Leadership loses confidence in the numbers. All of this stems from one root cause: the data model was never designed around the actual journey the customer takes.

### The Universal Customer Journey

For every person, there is a unique idea and approach to anything. Yet at the most dissected tier of methodology, the most common supporting data across industries and organizations follows the same logical progression:

1. **Customer** — Who is asking?
2. **Customer Request** — What are they asking for?
3. **Estimate** — What will it take to fulfill the request?
4. **Quote** — What is the formal offer?
5. **Order** — What has been agreed upon?
6. **Delivery** — What was actually delivered, and when?
7. **Adjustments** — What changed along the way?
8. **Customer Response** — How did the customer react?

This sequence is not a sales funnel — it is a data lineage. Each step creates a record that references the step before it. This chain of references is what allows you to trace any outcome back to its origin: a delivery dispute back to the original quote, a profitability variance back to the estimate, a customer churn signal back to unresolved adjustments.

### Tier I: The Foundation Baseline

"Tier I" is the first layer we will build upon to develop a stronger knowledge base. It is not a complete picture of your business — it is intentionally minimal. The goal is to establish a clean, unambiguous foundation before adding complexity.

The Tier I schema across all eight entities is presented in this chapter and formalized in the accompanying schema workbook (`schema/Customer_Processing_Schema.xlsx`). Each table is defined with a primary key, the appropriate foreign keys linking it to prior steps in the journey, and the minimum attributes needed to answer the six baseline questions:

1. How many open orders exist?
2. How many customers do we have?
3. What is our delivery rate?
4. How is our customer satisfaction?
5. Who are our most profitable customers?
6. Who are our new customers?

These six questions form the analytical foundation of every sales operation. Every subsequent chapter adds new questions — and with them, new data — but none of them replace these six. They remain the baseline health check throughout this textbook.

### Reflection

What other questions can you already see that this Tier I structure could answer? Before reading further, take a moment to look at the schema and list three questions you believe it can support. Then list three questions you suspect it *cannot* yet answer. The second list will become the roadmap for the chapters ahead.

---

## Chapter Structure

This textbook is organized in progressive tiers. Each chapter introduces:

- A new **business question** or analytical need
- The **data gaps** that prevent answering it with the current schema
- New **attributes or tables** (Tier II, III, etc.) added to the model
- **SQL examples** demonstrating how to query the expanded schema
- A **reflection section** prompting the reader to apply the concept to their own context

### Chapter Outline

| Chapter | Title | Tier Introduced | Key Topics |
|---------|-------|-----------------|------------|
| Introduction | The Customer's Data Journey | Tier I | Schema foundations, the 8-step journey, baseline KPIs |
| Chapter 1 | Knowing Your Customer | Tier I → II | Contact data, customer segmentation, account hierarchy |
| Chapter 2 | Capturing the Request | Tier I → II | Request types, product vs. service workflows, request metadata |
| Chapter 3 | Estimating with Confidence | Tier II | Cost vs. price modeling, margin tracking, SKU introduction |
| Chapter 4 | Quoting for Clarity | Tier II | Quote versioning, approval workflows, expiry tracking |
| Chapter 5 | Managing the Order | Tier II → III | Order lines, quantities, scheduling, partial fulfillment |
| Chapter 6 | Delivering on the Promise | Tier III | Delivery tracking, actual vs. promised dates, carrier data |
| Chapter 7 | When Things Change | Tier III | Adjustment types, root cause analysis, financial impact |
| Chapter 8 | The Customer's Voice | Tier III | Response scoring, NPS integration, feedback loops |
| Chapter 9 | Measuring Performance | Tier III → IV | KPI design, dashboard logic, period-over-period analysis |
| Chapter 10 | Building a Sales Intelligence System | Tier IV | Full schema assembly, CRM integration, automation |

---

## Tier I Schema Reference

The following tables constitute the Tier I foundation. Each table name corresponds to a worksheet in the accompanying schema workbook.

### Customer

The anchor of the entire data model. Every record in every other table ultimately links back here.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `cust_id` | Customer ID | Primary key |
| `cust_type` | Customer Type | e.g., Direct, Reseller, Internal |
| `cust_name` | Customer Name | Legal or preferred name |
| `cust_branch` | Customer Branch | Division, location, or business unit |

### Request

Captures the initial expression of need from the customer. The `req_delivery_date` field is the customer's stated or implied target — the "when" of their ask. It is the anchor for all downstream date comparisons across the estimate, quote, and order.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `req_id` | Request ID | Primary key |
| `cust_id` | Customer ID | Foreign key → Customer |
| `req_type` | Request Type | e.g., New, Renewal, Change |
| `cust_req` | Customer Request | Free-text or structured description |
| `req_delivery_date` | Requested Delivery Date | The date the customer needs delivery; the origin point for all scheduling comparisons downstream |

### Estimate

The internal assessment of what it will take to fulfill the request.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `est_id` | Estimate ID | Primary key |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `est_shipment_date` | Estimated Delivery Date | Internal working estimate |
| `est_cost` | Estimated Cost | Internal cost to fulfill |
| `est_price` | Estimated Price | Price to present to customer |
| `est_alerts` | Estimate Alerts | Flags for risk, capacity, or dependency issues |

### Quote

The formal offer presented to the customer.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `qte_id` | Quote ID | Primary key |
| `est_id` | Estimate ID | Foreign key → Estimate |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `qte_shipment_date` | Quoted Delivery Date | Committed date in the offer |
| `qte_cost` | Quoted Cost | Cost basis for the quote |
| `qte_price` | Quoted Price | Price offered to the customer |

### Order

The confirmed agreement to fulfill the request at the quoted terms.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `ord_id` | Order ID | Primary key |
| `qte_id` | Quote ID | Foreign key → Quote |
| `est_id` | Estimate ID | Foreign key → Estimate |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `ord_exp_date` | Expected Delivery Date | Operational target date |
| `ord_cost` | Order Cost | Confirmed cost |
| `ord_price` | Order Price | Confirmed price |

### Delivery

The record of what was actually delivered and when.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `del_id` | Delivery ID | Primary key |
| `ord_id` | Order ID | Foreign key → Order |
| `qte_id` | Quote ID | Foreign key → Quote |
| `est_id` | Estimate ID | Foreign key → Estimate |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `del_date` | Delivery Date | Actual delivery date |

### Adjustment

Any change to a prior record — financial, logistical, or qualitative.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `adj_id` | Adjustment ID | Primary key |
| `del_id` | Delivery ID | Foreign key → Delivery |
| `ord_id` | Order ID | Foreign key → Order |
| `qte_id` | Quote ID | Foreign key → Quote |
| `est_id` | Estimate ID | Foreign key → Estimate |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `adj_type` | Adjustment Type | e.g., Price, Date, Quantity, Credit |
| `adj_reason` | Adjustment Reason | Explanation of why the change occurred |
| `adj_del` | Delivery Date Adjustment | Revised delivery date (if changed) |
| `adj_cost` | Cost Adjustment | Change in cost |
| `adj_price` | Price Adjustment | Change in price |

### Response

The customer's reaction after delivery — the closing record of the cycle.

| Column Name | Attribute Name | Notes |
|-------------|---------------|-------|
| `resp_id` | Customer Response ID | Primary key |
| `del_id` | Delivery ID | Foreign key → Delivery |
| `ord_id` | Order ID | Foreign key → Order |
| `qte_id` | Quote ID | Foreign key → Quote |
| `est_id` | Estimate ID | Foreign key → Estimate |
| `req_id` | Request ID | Foreign key → Request |
| `cust_id` | Customer ID | Foreign key → Customer |
| `cust_response` | Customer Response | Feedback, satisfaction score, or follow-up request |

---

## A Note on Foreign Key Redundancy

You may have noticed that several tables carry the full chain of foreign keys — `cust_id`, `req_id`, `est_id`, etc. — even when they are technically derivable by joining through parent tables. This is an intentional design choice for Tier I.

At this early stage, having direct references at each level provides two benefits:
1. **Query simplicity** — analysts can join directly to any record without traversing multiple tables.
2. **Audit transparency** — every record knows its complete lineage without requiring a join.

As the schema matures in later tiers, some of this redundancy is deliberately normalized out in favor of cleaner relational design. Chapter 4, for example, renames `est_id` on the `quote` table to `qte_est_id` to align with the `qte_` naming convention, and Chapter 5 replaces the single `ord_exp_date` field with two purpose-specific date fields — `ord_promised_date` and `ord_scheduled_date` — because a single field can no longer represent the operational reality. Each of these changes is documented with a supersession note in the relevant chapter. For now, clarity wins over purity.

---

## How to Use This Textbook

Each chapter follows a consistent structure:

1. **Business Context** — The real-world situation motivating the new data need
2. **The Data Gap** — What the current schema cannot answer
3. **Schema Update** — New columns or tables, with rationale
4. **Analytical Application** — SQL queries, example reports, or KPI definitions
5. **Reflection** — Questions to apply the concept in your own organization

The schema workbook (`schema/Customer_Processing_Schema.xlsx`) is updated alongside each chapter. Each worksheet maps to a table, and the **Tier** column tracks when each attribute was introduced. This allows you to implement the model incrementally — you do not need to build everything at once.

---

*Phase I complete. The database implementation supporting this schema is built in Phase II using Supabase. The CRM application implementing these concepts with live data is available in Phase III.*

---

**[Next Chapter → Chapter 1: Knowing Your Customer](01-knowing-your-customer.md)**
