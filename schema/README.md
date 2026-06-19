# Schema

This folder contains the complete data model for the textbook as a set of cumulative workbooks — one per tier boundary, plus the full complete schema.

---

## Workbooks

| File | Tiers | Tables | Fields | Description |
|------|-------|--------|--------|-------------|
| `Schema_Tier_I.xlsx` | I | 8 | 58 | Foundation schema only — the minimal baseline from the Introduction |
| `Schema_Tier_I_II.xlsx` | I–II | 14 | 135 | Adds contacts, users, SKUs, and line-level detail (Chapters 1–5) |
| `Schema_Tier_I_III.xlsx` | I–III | 16 | 169 | Full transactional schema incl. fulfillment, adjustments, and responses (Chapters 6–8) |
| `Schema_Complete_Tier_I_IV_updated.xlsx` | I–IV | 17 | 193 | Complete schema including the reporting layer (Chapters 1–10) |

> **Note:** `Schema_Tier_I.xlsx` and `Schema_Tier_I_II.xlsx` have been generated but not yet uploaded to this folder.

Each workbook contains:
- A **Legend** sheet explaining tier colors and scope
- An **ALL FIELDS** sheet with every table and column in journey order
- One **sheet per table**, color-coded by the tier in which each field was introduced

---

## Tier Color Key

| Tier | Color | Introduced In |
|------|-------|---------------|
| Tier I | Yellow | Introduction — 8 core tables, minimum viable schema |
| Tier II | Green | Chapters 1–5 — Contacts, users, SKUs, line-level detail |
| Tier III | Blue | Chapters 6–8 — Fulfillment tracking, adjustments, customer responses |
| Tier IV | Pink | Chapters 9–10 — Reporting layer: period, kpi_definition, kpi_snapshot |

---

## Table Inventory (Complete Schema)

| Table | First Tier | Purpose |
|-------|------------|---------|
| `customer` | I | Anchor of the entire data model |
| `contact` | II | Customer-side contacts |
| `user` | II | Internal staff (assignments, approvals) |
| `request` | I | Initial expression of need |
| `sku` | II | Product and service catalog |
| `estimate` | I | Internal cost and price assessment |
| `estimate_line` | II | Line-level estimate detail |
| `quote` | I | Formal offer to the customer |
| `quote_line` | II | Line-level quote detail |
| `order` | I | Confirmed commitment |
| `order_line` | II/III | Order lines; fulfillment status added in Tier III |
| `delivery` | I | Record of what was delivered and when |
| `adjustment` | I | Any change to a prior record |
| `response` | I | Customer reaction after delivery |
| `period` | IV | Named reporting periods with prior-period linkage |
| `kpi_definition` | IV | Formal KPI definitions |
| `kpi_snapshot` | IV | Pre-calculated metric values per period/segment |

---

## Updating the Schema

When a chapter introduces schema changes:
1. Update `Schema_Complete_Tier_I_IV_updated.xlsx`
2. Regenerate the per-tier workbooks from the complete file
3. Update the Table Inventory above if a new table is added
4. Commit with message: `schema: tier [X] — [brief description]`
