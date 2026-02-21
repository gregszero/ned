# Canvas & Widgets Guide

Pages are infinite canvases. Use `add_canvas_component` to place positioned widgets on them, or `build_canvas` to create a full page with multiple components in one call.

## Spatial Layout Guidelines
- Space components **~400px apart** vertically for comfortable reading
- Use widths between **300–600px** (default 320)
- Start first component at roughly **(100, 100)**
- Use `get_canvas` first to see what's already on the canvas before adding
- Content is HTML — use the design system classes for styling

## build_canvas (Batch Tool)

Create a page with multiple widgets in a single call:
```json
{
  "title": "Dashboard",
  "layout": "grid",
  "components": [
    { "type": "metric", "metadata": { "label": "Users", "value": "42", "data_source": "User.count" } },
    { "type": "chart", "metadata": { "chart_type": "bar", "title": "Daily Messages", "labels": ["Mon","Tue","Wed"], "datasets": [{"label": "Count", "data": [10,20,15]}] } },
    { "type": "table", "metadata": { "title": "Tasks", "columns": ["Name","Status"], "rows": [["Deploy","done"]], "data_source": "ScheduledTask.limit(10).map{|t|[t.title,t.status]}" } }
  ]
}
```

**Layouts:** `grid` (2-column, auto-positioned), `stack` (single column), `freeform` (explicit x/y per component)

## Widget Types

Use `component_type` in `add_canvas_component` to create rich widgets. Pass structured `metadata` instead of raw HTML content.

| Type | Purpose | Key metadata |
|---|---|---|
| `card` | Free-form HTML note (default) | `text` |
| `chart` | Chart.js chart (bar, line, pie, etc.) | `chart_type`, `title`, `labels`, `datasets`, `options` |
| `metric` | Single big number with trend | `value`, `label`, `trend`, `trend_direction` (up/down), `data_source` |
| `table` | Sortable data table | `title`, `columns`, `rows`, `sortable`, `data_source` |
| `list` | Item list with optional links | `title`, `items: [{text, subtitle, url}]`, `data_source` |
| `banner` | Colored notification banner | `message`, `banner_type` (info/success/warning/error) |
| `clock` | Live clock | `timezone`, `label` |

### Chart Widget Example
```json
{
  "component_type": "chart",
  "metadata": {
    "chart_type": "bar",
    "title": "Messages per Day",
    "labels": ["Mon", "Tue", "Wed", "Thu", "Fri"],
    "datasets": [{
      "label": "Messages",
      "data": [12, 19, 8, 15, 22],
      "backgroundColor": "rgba(124, 58, 237, 0.6)"
    }]
  }
}
```

### Metric Widget Example
```json
{
  "component_type": "metric",
  "metadata": {
    "label": "Total Conversations",
    "value": "42",
    "trend": "+5 this week",
    "trend_direction": "up",
    "data_source": "Conversation.count"
  }
}
```

### Table Widget Example
```json
{
  "component_type": "table",
  "metadata": {
    "title": "Scheduled Tasks",
    "columns": ["Title", "Status", "Scheduled"],
    "rows": [["Deploy", "pending", "2025-01-15"]],
    "sortable": true,
    "data_source": "ScheduledTask.limit(20).map { |t| [t.title, t.status, t.scheduled_for&.strftime('%Y-%m-%d')] }"
  }
}
```

## Data Binding (Auto-Refresh)

Widgets with a `data_source` metadata key auto-refresh every 5 minutes via `WidgetRefreshJob`. The value is a Ruby expression evaluated with all ActiveRecord models available:
- `"Message.count"` → returns a number (for metric widgets)
- `"ScheduledTask.limit(10).map { |t| [t.title, t.status] }"` → returns an array (for table widgets)
- `"Notification.recent.limit(5).map { |n| { 'text' => n.title, 'subtitle' => n.created_at.strftime('%b %d') } }"` → returns items (for list widgets)

## Action Buttons

Embed interactive buttons in widget HTML that POST to `/api/actions`:

```html
<button data-fang-action='{"action_type":"run_skill","skill_name":"deploy"}'>Deploy</button>
<button data-fang-action='{"action_type":"run_code","code":"ScheduledTask.find(1).update!(status: \"cancelled\")"}'>Cancel</button>
<button data-fang-action='{"action_type":"refresh_component","component_id":5}'>Refresh</button>
<button data-fang-action='{"action_type":"send_message","conversation_id":1,"content":"Status update please"}'>Ask Status</button>
```

Buttons automatically show loading/success/error states. Use `data-loading-text` and `data-success-text` attributes to customize.

## Defining New Widget Types

Use `define_widget` to create entirely new widget types at runtime:
- `widget_type`: snake_case name (e.g. "countdown_timer")
- `ruby_code`: Full Ruby class inheriting from `Fang::Widgets::BaseWidget`
- `js_code`: Optional JS behavior registered via `registerWidget('type', { init(el, meta) {}, destroy(el) {} })`
- The new widget appears in the canvas context menu immediately
