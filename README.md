# Customer Sales Data: A Practical Guide

> *A textbook for service and product suppliers on organizing, understanding, and acting on customer data.*

---

## What This Is

This repository is the working home of **Customer Sales Data: A Practical Guide** — a progressive, hands-on textbook built for people who work inside sales operations, customer success, order management, and business intelligence teams.

It does not assume you are a data scientist. It assumes you work with customers, handle transactions, and have at some point asked: *"Why can't I just get a straight answer from our data?"*

The answer almost always lies in the foundation. This textbook builds that foundation — from a single customer record to a fully operational sales intelligence system — one tier at a time.

---

## The Customer's Data Journey

At the core of this textbook is a simple idea: every customer interaction follows a logical sequence, and every step in that sequence creates a data record. Understanding that chain — and designing your data around it — is what separates reactive reporting from genuine sales intelligence.

The eight steps of the journey:

| # | Step | The Question It Answers |
|---|------|-------------------------|
| 1 | Customer | Who is asking? |
| 2 | Request | What are they asking for? |
| 3 | Estimate | What will it take to fulfill? |
| 4 | Quote | What is the formal offer? |
| 5 | Order | What has been agreed upon? |
| 6 | Delivery | What was delivered, and when? |
| 7 | Adjustment | What changed along the way? |
| 8 | Response | How did the customer react? |

---

## How This Textbook Is Built

The textbook is organized in **progressive tiers**. Tier I establishes the minimum viable schema — the data foundation that answers the six baseline questions every sales operation should be able to answer on day one:

1. How many open orders exist?
2. How many customers do we have?
3. What is our delivery rate?
4. How is our customer satisfaction?
5. Who are our most profitable customers?
6. Who are our new customers?

Each subsequent chapter introduces a new business question, identifies the data gap in the current schema, and expands the model to close it. By the end, you have a schema capable of supporting a modern CRM.

---

## Repository Structure

```
customer-sales-data-practical/
│
├── chapters/        # Textbook chapter markdown files
├── schema/          # Schema workbook and reference files (Customer Processing.xlsx)
├── assets/          # Images, diagrams, and supporting visuals
├── database/        # SQL migrations and Supabase configuration (Phase II)
└── crm/             # CRM application source code and GitHub Pages setup (Phase III)
```

---

## Project Phases

### Phase I — The Textbook *(current)*
Developing chapter content and the progressive schema workbook. Each chapter is a markdown file in `/chapters`. The schema workbook in `/schema` is updated alongside each chapter to reflect new Tier attributes.

### Phase II — The Database
Once the schema is finalized, the full data model will be implemented in **Supabase**. Migration files and configuration will live in `/database`.

### Phase III — The CRM Application
A homemade CRM application hosted via **GitHub Pages** will implement the concepts discussed in the textbook using dummy records. It will also provide:
- A downloadable PDF of the full textbook
- A link to this repository

---

## Status

| Phase | Status |
|-------|--------|
| Phase I — Textbook | 🟡 In Progress |
| Phase II — Database | ⬜ Pending |
| Phase III — CRM App | ⬜ Pending |

---

*Built by [André Maurice Davis](https://andremauricedavis.com/) · [207 Analytix](https://github.com/andredavisme)*
