# Dynamic Data Tables Guide

Create real SQLite tables on the fly for structured data. Tables use a `dt_` prefix to avoid conflicts with framework tables.

## Creating a table
```json
{
  "name": "Customers",
  "columns": [
    {"name": "email", "type": "string", "required": true},
    {"name": "company", "type": "string"},
    {"name": "revenue", "type": "decimal"},
    {"name": "active", "type": "boolean"}
  ]
}
```
**Column types:** string, text, integer, decimal, boolean, date, datetime, json

## CRUD operations
- `insert_data_record` — insert a row with attributes matching the schema
- `query_data_table` — filter (`=`, `!=`, `>`, `<`, `like`), sort, and paginate
- `update_data_record` — update a row by record ID
- `delete_data_record` — delete a row by record ID

## Advanced queries
For complex joins, aggregations, or cross-table queries beyond the CRUD tools, use `run_code` directly. The physical table name is in the `table_name` field (e.g., `dt_customers`).
