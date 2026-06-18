# Schema

This folder contains the evolving data model for the textbook.

## Files

| File | Description |
|------|-------------|
| `Customer_Processing_Schema.xlsx` | The primary schema workbook. Each worksheet is a table. The **Tier** column tracks when each attribute was introduced. |

## Tier History

| Tier | Introduced In | Description |
|------|--------------|-------------|
| I | Introduction | Foundation baseline — 8 tables, minimum viable attributes |

## Updating the Schema

When a new chapter introduces schema changes:
1. Add new columns to the appropriate worksheet with the new Tier label
2. Add new worksheets for any new tables
3. Update the Tier History table above
4. Commit with message: `schema: tier [X] — [brief description]`
