# Documents Guide

Upload, parse, and generate files. Documents are stored in `workspace/documents/` and their text is extracted for agent use.

**Supported formats:** PDF, CSV, Excel (xlsx/xls/ods), plain text, JSON, and other text-based formats.

## Uploading documents
Users can upload files via `POST /documents` (multipart form). Documents are auto-parsed on upload.

## Reading document content
Use `read_document` to get the extracted text. If the document hasn't been parsed yet, it auto-parses on first read. Pass `reparse: true` to force re-extraction.

## Creating documents programmatically
Use `create_document` to generate files:
- **Text files**: Pass content directly (CSV, JSON, markdown, etc.)
- **Binary files**: Pass base64-encoded content with `encoding: "base64"`

### Example — generate a CSV report
```json
{
  "name": "sales_report.csv",
  "content": "Name,Amount,Date\nAcme Corp,5000,2026-02-20\nGlobex,3200,2026-02-19",
  "description": "Weekly sales report"
}
```
