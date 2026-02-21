# OpenFang — Claude Code Guide

## What This Is

A personal AI assistant framework ("OpenFang") built in Ruby. It combines a Roda web UI, ActiveRecord models (SQLite), FastMCP tool server, and a Claude Code CLI subprocess as the agent runtime.

## Architecture

```
openfang.rb (entrypoint) → Fang::CLI (Thor)
├── web/app.rb            Roda web server (port 3000)
├── fang/mcp_server.rb    FastMCP tool server (port 9292)
├── fang/agent.rb         Spawns `claude` CLI subprocess per conversation
├── fang/bootstrap.rb     Loads everything, connects DB
├── fang/scheduler.rb     Rufus-scheduler for recurring tasks
├── fang/computer_use/    Browser automation (Playwright)
├── fang/document_parser.rb  Multi-format text extraction
├── fang/python_runner.rb    Python virtualenv and execution
└── fang/gmail.rb            Gmail OAuth2 integration
```

**Real-time updates**: In-memory pub/sub (`web/turbo_broadcast.rb`) → SSE → Turbo Streams in the browser. No ActionCable or Redis needed — everything runs in one process.

**Agent execution**: When a user sends a message, `AgentExecutorJob` runs `Fang::Agent.execute`, which spawns a `claude` CLI subprocess with MCP tools. The subprocess uses `workspace/.mcp.json` and `workspace/CLAUDE.md` as its system prompt.

## Key Conventions

- **Auto-discovery via ObjectSpace**: MCP tools (`fang/tools/`) and resources (`fang/resources/`) are auto-registered by scanning for subclasses of `FastMcp::Tool` and `FastMcp::Resource`. Just create the file — no manual registration needed.
- **No index pages for content types**: When the AI creates a new page/content type, add a direct link to it in the nav bar (`web/views/layout.erb`) instead of creating a separate listing page. Each page is served at `/pages/:slug`.
- **Models use concerns**: Shared behavior lives in `fang/concerns/` (e.g., `HasStatus`, `HasJsonDefaults`).

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
| `--background` | `#c8ccd1` | `#1a1a1e` | Page background |
| `--foreground` | `#0f172a` | `#fafafa` | Primary text |
| `--card` | `#dde0e4` | `#242428` | Card backgrounds |
| `--muted` | `#b8bcc2` | `#2e2e33` | Muted backgrounds |
| `--muted-foreground` | `#4a5568` | `#9a9aaa` | Muted text |
| `--primary` | `#16a34a` | `#16a34a` | Accent (green) |
| `--primary-foreground` | `#ffffff` | `#ffffff` | Text on accent |
| `--border` | `#a8adb4` | `#3a3a40` | Borders |
| `--ring` | `#16a34a` | `#16a34a` | Focus rings |

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
- `WorkflowRunnerJob` → `workflow:completed:*` / `workflow:failed:*`
- `Approval` → `approval:approved:*` / `approval:rejected:*` / `approval:expired:*`

**Triggers** (`fang/models/trigger.rb`) match events via glob patterns and fire a skill or prompt.

**Workflows** (`fang/models/workflow.rb`) are multi-step pipelines with step types: `skill`, `prompt`, `condition`, `wait`, `notify`, `approval`. Steps pass data via a JSON context hash with `{{context.step_name}}` interpolation. Workflows can auto-start on a `trigger_event`.

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
| `fang/skill_loader.rb` | Skill discovery and execution |
| `fang/python_runner.rb` | Python virtualenv and code execution |
| `fang/document_parser.rb` | Multi-format document text extraction |
| `fang/gmail.rb` | Gmail OAuth2 integration |
| `fang/whatsapp.rb` | WhatsApp message routing |
| `fang/system_profile.rb` | Host system capability detection |
| `workspace/CLAUDE.md` | OpenFang's system prompt (the inner agent reads this) |
| `workspace/.mcp.json` | MCP config passed to claude subprocess |

## Existing MCP Tools (38 total)

All tools live in `fang/tools/` and are auto-discovered via ObjectSpace.

| Category | Tool | Purpose |
|---|---|---|
| **Core** | `run_code` | Execute Ruby code with model access |
| | `run_skill` | Execute saved skills by name |
| | `manage_python` | Run Python code, manage virtualenv and dependencies |
| | `send_message` | Send message + broadcast via SSE |
| **Scheduling** | `schedule_task` | Schedule future tasks/reminders (supports `cron:` for recurring) |
| **Pages & Canvas** | `create_page` | Create Page (appears in nav) |
| | `get_canvas` | Read current page's widget layout |
| | `update_canvas` | Set page HTML content |
| | `add_canvas_component` | Add a widget to the canvas |
| | `update_canvas_component` | Modify a widget's position/content/data |
| | `remove_canvas_component` | Remove a widget |
| | `define_widget` | Create a new widget type (writes Ruby to disk) |
| **Documents** | `create_document` | Upload or generate a document |
| | `read_document` | Read extracted text from a document |
| | `list_documents` | List documents in a conversation |
| **Data Tables** | `create_data_table` | Create a dynamic SQLite table with custom schema |
| | `list_data_tables` | List all dynamic data tables |
| | `query_data_table` | Query records with filtering and sorting |
| | `insert_data_record` | Insert a row into a data table |
| | `update_data_record` | Update a row in a data table |
| | `delete_data_record` | Delete a row from a data table |
| **Approvals** | `create_approval` | Create a human-in-the-loop approval gate |
| | `list_approvals` | List pending and resolved approvals |
| | `resolve_approval` | Approve or reject a pending approval |
| **Automation** | `create_notification` | Create + broadcast notification |
| | `create_trigger` | Create event trigger (fires skill/prompt on matching event) |
| | `create_workflow` | Create multi-step workflow pipeline |
| | `create_heartbeat` | Set up a token-efficient monitor |
| | `update_heartbeat` | Modify a heartbeat's config |
| | `list_heartbeats` | View all heartbeats and their stats |
| **Web** | `web_fetch` | HTTP requests (GET/POST/PUT/PATCH/DELETE) |
| | `start_computer_use` | Launch a browser automation session |
| **Gmail** | `gmail_search` | Search Gmail messages |
| | `gmail_read` | Read a Gmail message by ID |
| | `gmail_send` | Send an email via Gmail |
| | `gmail_draft` | Create a Gmail draft |
| | `gmail_modify` | Modify Gmail message labels (archive, star, etc.) |
| | `gmail_labels` | List available Gmail labels |
