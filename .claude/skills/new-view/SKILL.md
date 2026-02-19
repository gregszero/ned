# Create a New View/Route

Adds a new page to the Roda web UI.

## Steps

### 1. Add Route to `web/app.rb`

Add inside the `route do |r|` block, following existing patterns:

```ruby
r.on 'my-page' do
  r.is do
    r.get do
      @my_data = Fang::MyModel.all
      view :my_page
    end
  end
end
```

### 2. Create ERB Template

Create `web/views/my_page.erb`:

```erb
<h2>Page Title</h2>

<div class="flex flex-col gap-4 mt-4">
  <% @my_data.each do |item| %>
    <div class="card">
      <h3 style="text-transform:none;"><%= item.title %></h3>
      <p class="text-fang-muted-fg text-sm mt-1"><%= item.description %></p>
    </div>
  <% end %>
</div>
```

### 3. Add Nav Link to `web/views/layout.erb`

Add inside the `<nav>` element in the sidebar:

```erb
<a href="/my-page">My Page</a>
```

**Convention**: No separate index pages for content types. Each page gets its own nav link.

## Design System Quick Reference

### Layout
- Use Tailwind utilities: `flex`, `gap-4`, `mt-4`, `p-6`, `max-w-7xl`
- Custom colors: `text-fang-fg`, `bg-fang-card`, `border-fang-border`, `text-fang-accent`, `text-fang-muted-fg`

### Components
- **Card**: `<div class="card">` — bordered, dark bg, hover accent
- **Badge**: `<span class="badge info">Label</span>` — variants: `success`, `error`, `warning`, `info`
- **Button**: `<button class="sm">Click</button>` — variants: `.ghost`, `.outline`, `.sm`, `.xs`, `.icon`
- **Table**: Standard `<table>` — auto-styled with borders and striping

### Typography
- All headings are uppercase + bold by default
- Use `style="text-transform:none;"` on headings that should be normal case
- Font: Space Grotesk (loaded via Google Fonts CDN)

### SSE Streaming (real-time updates)

If the page needs live updates:

1. Add an SSE stream route:
```ruby
r.on 'my-page', 'stream' do
  r.get do
    sse_stream('my-channel')
  end
end
```

2. Connect in the ERB template:
```html
<div id="my-target"></div>
<script type="module">
  const es = new EventSource('/my-page/stream');
  es.onmessage = (e) => {
    document.getElementById('my-target').insertAdjacentHTML('beforeend', e.data);
  };
</script>
```

3. Broadcast from Ruby:
```ruby
Fang::Web::TurboBroadcast.broadcast('my-channel', turbo_html)
```
