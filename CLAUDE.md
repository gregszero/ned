# OpenFang — Claude Code Guide

## What This Is

A personal AI assistant framework ("OpenFang") built in Ruby. It combines a Roda web UI, ActiveRecord models (SQLite), FastMCP tool server, and a Claude Code CLI subprocess as the agent runtime.

## Architecture

```
openfang.rb (entrypoint) → Fang::CLI (Thor)
├── web/app.rb          Roda web server (port 3000)
├── fang/mcp_server.rb    FastMCP tool server (port 9292)
├── fang/agent.rb         Spawns `claude` CLI subprocess per conversation
├── fang/bootstrap.rb     Loads everything, connects DB
└── fang/scheduler.rb     Rufus-scheduler for recurring tasks
```

**Real-time updates**: In-memory pub/sub (`web/turbo_broadcast.rb`) → SSE → Turbo Streams in the browser. No ActionCable or Redis needed — everything runs in one process.

**Agent execution**: When a user sends a message, `AgentExecutorJob` runs `Fang::Agent.execute`, which spawns a `claude` CLI subprocess with MCP tools. The subprocess uses `workspace/.mcp.json` and `workspace/CLAUDE.md` as its system prompt.

## Key Conventions

- **Auto-discovery via ObjectSpace**: MCP tools (`fang/tools/`) and resources (`fang/resources/`) are auto-registered by scanning for subclasses of `FastMcp::Tool` and `FastMcp::Resource`. Just create the file — no manual registration needed.
- **No index pages for content types**: When the AI creates a new page/content type, add a direct link to it in the nav bar (`web/views/layout.erb`) instead of creating a separate listing page. Each page is served at `/pages/:slug`.
- **Models use concerns**: Shared behavior lives in `fang/concerns/` (e.g., `HasStatus`).

## Running the App

```bash
./openfang.rb server        # Start web UI on port 3000
./openfang.rb console       # IRB with all models loaded
./openfang.rb db:migrate    # Run pending migrations
./openfang.rb mcp           # Start MCP server standalone
```

## Adding a New MCP Tool

1. Create `fang/tools/my_tool.rb`:

```ruby
# frozen_string_literal: true

module Fang
  module Tools
    class MyTool < FastMcp::Tool
      tool_name 'my_tool'
      description 'What this tool does'

      arguments do
        required(:name).filled(:string).description('Argument description')
        optional(:option).filled(:string).description('Optional argument')
      end

      def call(name:, option: nil)
        # Tool logic here — all Fang:: models are available
        { success: true, result: 'done' }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
```

2. Restart the server. The tool is auto-discovered.

## Adding a Route/View

1. Add route in `web/app.rb` following Roda `r.on` / `r.is` patterns
2. Create ERB template in `web/views/`
3. Add nav link in `web/views/layout.erb` sidebar `<nav>` section

## Adding a Model

1. Create migration in `workspace/migrations/YYYYMMDDNNNNNN_description.rb`:

```ruby
class CreateThings < ActiveRecord::Migration[8.0]
  def change
    create_table :things do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
```

2. Create model in `fang/models/thing.rb`:

```ruby
module Fang
  class Thing < ActiveRecord::Base
    self.table_name = 'things'
  end
end
```

3. Run `./openfang.rb db:migrate`

## Adding an API Client

`Fang::ApplicationClient` (`fang/application_client.rb`) is a base HTTP client using `Net::HTTP`. Subclasses get their own `Response`, `Error`, `NotFound`, etc. classes automatically.

1. Create `fang/clients/my_service_client.rb`:

```ruby
# frozen_string_literal: true

module Fang
  module Clients
    class MyService < ApplicationClient
      BASE_URI = "https://api.myservice.com/v1"

      # Override if the API uses a different auth scheme
      # def authorization_header = { "X-API-Key" => token }

      def widgets
        get("/widgets")
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to fetch widgets"
      end

      def create_widget(name:)
        post("/widgets", body: { name: name })
      end
    end
  end
end
```

2. Restart the server. Clients in `fang/clients/` are auto-loaded.

### Key features

- **HTTP methods**: `get`, `post`, `patch`, `put`, `delete` — all accept `headers:`, `query:`, `body:`, `form_data:`
- **JSON by default**: Request bodies are serialized to JSON. Responses with `application/json` are parsed to `OpenStruct` for dot-access (e.g., `response.name`).
- **Auth**: Pass `token:` on init. Override `authorization_header` for non-Bearer schemes.
- **Error handling**: Raises typed errors (`NotFound`, `Unauthorized`, `RateLimit`, etc.). Rescue `*NET_HTTP_ERRORS` for network failures.
- **Pagination**: `with_pagination(path) { |response| next_page_or_nil }` loops until the block returns nil.
- **Custom response parsers**: Override per-client with `Response::PARSER["text/html"] = ->(r) { Nokogiri::HTML(r.body) }`

### Usage

```ruby
client = Fang::Clients::MyService.new(token: ENV["MY_SERVICE_API_KEY"])
client.widgets          # => Response with dot-access to parsed JSON
client.create_widget(name: "Foo")
```

## Design System

Clean, minimal shadcn/ui-inspired design with terminal green accent. Supports light/dark mode via `prefers-color-scheme`. Inter font, rounded corners, subtle shadows.

### CSS Tokens (defined in `web/public/css/style.css`)

Light and dark mode tokens are defined as CSS custom properties. The `--fang-*` aliases are used by Tailwind classes.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `--background` | `#ffffff` | `#09090b` | Page background |
| `--foreground` | `#0f172a` | `#fafafa` | Primary text |
| `--card` | `#ffffff` | `#18181b` | Card backgrounds |
| `--muted` | `#f1f5f9` | `#27272a` | Muted backgrounds |
| `--muted-foreground` | `#64748b` | `#a1a1aa` | Muted text |
| `--primary` | `#16a34a` | `#22c55e` | Accent (green) |
| `--primary-foreground` | `#ffffff` | `#ffffff` | Text on accent |
| `--border` | `#e2e8f0` | `#27272a` | Borders |
| `--ring` | `#16a34a` | `#22c55e` | Focus rings |

### Components
- **`.card`** — rounded card with subtle border and shadow
- **`.badge`** — pill label (variants: `.success`, `.error`, `.warning`, `.info`)
- **`button`** — green bg, rounded. Variants: `.ghost`, `.outline`, `.sm`, `.xs`, `.icon`
- **`.chat-msg.user`** / **`.chat-msg.ai`** — rounded chat bubbles
- **`.prose-bubble`** — markdown content inside chat bubbles
- **`.section-heading`** — card section titles
- **`.msg-meta`** — chat message metadata (small, uppercase, muted)
- **`.notification-unread`** — unread notification left border accent
- **`.nav-trigger`** — hamburger menu button
- **`.notification-badge`** — small pill badge for notification counts

### Rules
- **No inline styles** — all styling via Tailwind utilities or CSS classes
- **No `text-transform: uppercase`** on headings — use `font-semibold tracking-tight`

Tailwind CSS is loaded via CDN with custom colors: `fang-bg`, `fang-fg`, `fang-muted`, `fang-muted-fg`, `fang-accent`, `fang-accent-fg`, `fang-border`, `fang-card`, `fang-primary`, `fang-ring`.

## Event System

`Fang::EventBus` is a simple in-process pub/sub for decoupled automation. Call `EventBus.emit("event:name", data)` to fire an event. Triggers and workflows listen for matching events.

**Emit points** are wired into:
- `ScheduledTaskRunnerJob` → `task:completed:*` / `task:failed:*`
- `HeartbeatRunnerJob` → `heartbeat:escalated:*` / `heartbeat:error:*`
- `Notification#broadcast!` → `notification:created:*`

**Triggers** (`fang/models/trigger.rb`) match events via glob patterns and fire a skill or prompt.

**Workflows** (`fang/models/workflow.rb`) are multi-step pipelines with step types: `skill`, `prompt`, `condition`, `wait`, `notify`. Steps pass data via a JSON context hash with `{{context.step_name}}` interpolation. Workflows can auto-start on a `trigger_event`.

## Key Files

| File | Purpose |
|---|---|
| `openfang.rb` | CLI entrypoint |
| `fang/bootstrap.rb` | Framework loader |
| `fang/agent.rb` | Claude subprocess execution |
| `fang/mcp_server.rb` | FastMCP tool/resource registration |
| `fang/application_client.rb` | Base HTTP API client (subclass for new integrations) |
| `fang/event_bus.rb` | In-process event pub/sub for triggers and workflows |
| `web/app.rb` | All Roda routes |
| `web/views/layout.erb` | Main layout with sidebar nav |
| `web/view_helpers.rb` | HTML rendering helpers (turbo_stream, markdown, message/notification cards) |
| `web/turbo_broadcast.rb` | In-memory pub/sub for SSE |
| `web/public/css/style.css` | Complete design system |
| `workspace/CLAUDE.md` | OpenFang's system prompt (the inner agent reads this) |
| `workspace/.mcp.json` | MCP config passed to claude subprocess |

## Existing MCP Tools

| Tool | File | Purpose |
|---|---|---|
| `run_code` | `fang/tools/run_code_tool.rb` | Execute Ruby code with model access |
| `run_skill` | `fang/tools/run_skill_tool.rb` | Execute saved skills by name |
| `send_message` | `fang/tools/send_message_tool.rb` | Send message + broadcast via SSE |
| `schedule_task` | `fang/tools/schedule_task_tool.rb` | Schedule future tasks/reminders (supports `cron:` for recurring) |
| `create_page` | `fang/tools/create_page_tool.rb` | Create Page (appears in nav) |
| `create_notification` | `fang/tools/create_notification_tool.rb` | Create + broadcast notification |
| `create_trigger` | `fang/tools/create_trigger_tool.rb` | Create event trigger (fires skill/prompt on matching event) |
| `create_workflow` | `fang/tools/create_workflow_tool.rb` | Create multi-step workflow pipeline |
