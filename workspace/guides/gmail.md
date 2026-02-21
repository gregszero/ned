# Gmail Guide

Use the `gmail_*` tools to manage the user's email. Common patterns:

- **Check unread**: `gmail_search` with query `is:unread` or `is:unread newer_than:1d`
- **Search by sender**: `gmail_search` with query `from:alice@example.com`
- **Read an email**: Get message IDs from `gmail_search`, then `gmail_read` for full content
- **Send email**: `gmail_send` with `to`, `subject`, `body` (set `html: true` for HTML emails)
- **Mark as read**: `gmail_modify` with `remove_labels: ["UNREAD"]`
- **Archive**: `gmail_modify` with `remove_labels: ["INBOX"]`
- **Star**: `gmail_modify` with `add_labels: ["STARRED"]`
- **Get label IDs**: Use `gmail_labels` to look up custom label IDs before modifying

Always use `gmail_search` first to find message IDs, then operate on them with other tools.
