# OpenFang

A personal AI assistant framework built in Ruby. One process, zero infrastructure. Claude thinks, Ruby acts.

OpenFang wraps the Claude Code CLI as an agent runtime and gives it a full toolkit: scheduled tasks, heartbeat monitors, event-driven workflows, persistent canvas pages, and an extensible skill system — all served through a real-time web UI.

---

## How It Works

```
You ──► Web UI ──► Conversation ──► Claude CLI subprocess
                                         │
                                         ▼
                                    MCP Tool Server
                                    ┌──────────────┐
                                    │  run_code     │
                                    │  run_skill    │
                                    │  schedule_task│
                                    │  create_page  │
                                    │  web_fetch    │
                                    │  ...38 tools  │
                                    └──────┬───────┘
                                           │
                                    ┌──────▼───────┐
                                    │  ActiveRecord │
                                    │  SQLite / PG  │
                                    └──────┬───────┘
                                           │
                                    ┌──────▼───────┐
                                    │  SSE / Turbo  │
                                    │  Streams      │
                                    └──────┬───────┘
                                           │
                                           ▼
                                    Real-time UI update
```

When you send a message, OpenFang spawns a `claude` CLI subprocess with access to 38 MCP tools. Claude can execute Ruby code, create pages, schedule tasks, build widgets, define skills, set up monitors — and every action streams back to your browser in real time via Server-Sent Events.

---

## Architecture

Everything runs in a single Puma process. No Redis. No Sidekiq. No ActionCable.

| Layer | Technology | Purpose |
|---|---|---|
| Web server | **Roda** + Puma | Lightweight routing, port 3000 |
| Agent runtime | **Claude CLI** subprocess | One subprocess per conversation |
| Tool protocol | **FastMCP** (SSE) | 38 tools + 6 resources exposed to Claude |
| Database | **ActiveRecord 8** + SQLite | Models, migrations, the usual |
| Background jobs | **ActiveJob** `:async` adapter | In-memory thread pool, no external deps |
| Scheduler | **Rufus-Scheduler** | Polls for due tasks every 60s, heartbeats every 30s |
| Real-time | **In-memory pub/sub** → SSE | Turbo Streams pushed to the browser |
| Templates | **ERB** + Tailwind CDN | shadcn/ui-inspired design system |

### Project Structure

```
openfang.rb                 # CLI entrypoint (Thor)
fang/
├── agent.rb                # Spawns claude CLI, streams NDJSON
├── bootstrap.rb            # Loads everything, connects DB
├── mcp_server.rb           # Auto-discovers tools & resources
├── scheduler.rb            # Rufus recurring jobs
├── event_bus.rb            # In-process pub/sub
├── skill_loader.rb         # Loads skills from skills/
├── models/                 # ActiveRecord models
├── tools/                  # MCP tools (auto-registered)
├── resources/              # MCP resources (auto-registered)
├── widgets/                # Canvas widget types
├── jobs/                   # ActiveJob classes
├── concerns/               # Shared model behavior
├── clients/                # API client integrations
├── computer_use/           # Browser automation (Playwright)
├── document_parser.rb      # Multi-format text extraction
├── python_runner.rb        # Python virtualenv and execution
├── gmail.rb                # Gmail OAuth2 integration
└── system_profile.rb       # Host system capability detection
web/
├── app.rb                  # All Roda routes
├── views/                  # ERB templates
├── turbo_broadcast.rb      # In-memory pub/sub → SSE
└── public/                 # Static assets, CSS, JS
skills/                     # Ruby skill files (auto-loaded)
workspace/
├── CLAUDE.md               # System prompt for the inner agent
├── .mcp.json               # MCP server config for subprocess
└── migrations/             # Database migrations
```

---

## Features

### Canvas Pages — Persistent, Widget-Based Dashboards

Every page in OpenFang is an infinite canvas. Claude creates pages with positioned widget components that persist across sessions. Pages auto-appear in the sidebar navigation.

Widgets are self-rendering Ruby classes. Built-in types include:

| Widget | What It Does |
|---|---|
| `metric` | Big number with trend indicator, auto-refreshes from data source |
| `chart` | Chart.js powered (bar, line, pie, doughnut) |
| `data_table` | Paginated, sortable, filterable table backed by any ActiveRecord model |
| `heartbeat_monitor` | Live status grid of all heartbeat monitors |
| `weather` | Current conditions via Open-Meteo API |
| `hacker_news` | Top stories from HN |
| `clock` | Live clock with configurable timezone |
| `note` | Editable markdown |
| `banner` | Colored alert bar |
| `list` | Items with optional links, auto-refresh from data source |
| `data_table` | Dynamic data table with full CRUD, backed by AI-created schemas |
| `approval` | Pending approval display with approve/reject actions |
| `computer_use` | Browser automation session viewer |
| `scheduled_jobs` | Upcoming and recent scheduled task overview |
| `settings` | Configuration key/value editor |
| `website` | Embedded website iframe |

Claude can also **define entirely new widget types at runtime** using the `define_widget` tool — writing the Ruby class to disk and hot-loading it without a restart.

Widgets that declare themselves `refreshable?` are auto-updated every 5 minutes by `WidgetRefreshJob`.

---

### Skills — Reusable Ruby Code That Saves Tokens

Skills are the core mechanism for **not wasting tokens on repeated work**. Instead of Claude regenerating the same logic each time, it writes a skill once:

```ruby
class WeatherCheck < Fang::Skill
  description "Check weather for a city"
  param :city, :string, required: true

  def call(city:)
    response = HTTParty.get("https://api.open-meteo.com/v1/forecast?...")
    { temperature: response["current"]["temperature_2m"] }
  end
end
```

After that, `run_skill weather_check city: "Portland"` executes in pure Ruby — no AI tokens spent. Skills have full access to all models and built-in helpers like `send_message`, `schedule_task`, and `run_query`.

The `run_code` tool lets Claude execute arbitrary Ruby with access to every ActiveRecord model. When a pattern emerges, it promotes one-off code into a named skill.

**Skills are auto-discovered** — drop a `.rb` file in `skills/` and it's available immediately.

---

### Scheduling — Cron, One-Shot, and Relative Times

The `schedule_task` tool handles any time-based request:

```
"Remind me in 2 hours"          → relative time parsing
"Run deploy check tomorrow"     → natural date parsing
"Every weekday at 9am"          → cron: "0 9 * * 1-5"
```

Scheduled tasks can either:
- **Run a skill** directly (zero tokens — pure Ruby execution)
- **Send a prompt** to the agent (creates a conversation, invokes Claude)

Recurring tasks use cron expressions (parsed by Fugit) and automatically schedule their next run after completion.

The scheduler polls every 60 seconds via Rufus-Scheduler. Completed and failed tasks emit events on the EventBus, enabling downstream automation.

---

### Heartbeats — Token-Efficient Monitoring

Heartbeats are the most token-efficient pattern in OpenFang. They solve the problem of "I want Claude to watch something, but I don't want to pay for constant AI polling."

**How it works:**

```
┌─────────────────────────────────────────────────────┐
│  Every 30 seconds, the scheduler checks due beats   │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│  Phase 1: Run skill in pure Ruby (ZERO tokens)       │
│  e.g., check disk space, query an API, count errors  │
└──────────────────────┬───────────────────────────────┘
                       │
              Is result meaningful?
              (not nil, not empty, not false)
                       │
            ┌──────────┴──────────┐
            │                     │
         NO ▼                  YES ▼
    ┌───────────┐        ┌─────────────────┐
    │  Skip.    │        │  NOW invoke the  │
    │  Log it.  │        │  agent with the  │
    │  Move on. │        │  result data.    │
    │  (free)   │        │  (tokens spent)  │
    └───────────┘        └─────────────────┘
```

A heartbeat that checks disk space every 5 minutes will run the skill 288 times per day. If the disk is fine, that's 288 free checks. The moment it crosses a threshold, *then* Claude gets involved to analyze and respond.

The `heartbeat_monitor` widget shows a live dashboard with run history sparkbars and a visible "skipped (tokens saved)" counter.

Each heartbeat has a `prompt_template` with interpolation:

```
"Disk usage on {{name}} returned: {{result}}. Analyze and take action if needed."
```

---

### Events, Triggers, and Workflows

**EventBus** is an in-process pub/sub that ties the system together:

```ruby
EventBus.emit("task:completed:deploy", { task_id: 5 })
```

Events are emitted automatically by:
- Scheduled task completion/failure → `task:completed:*` / `task:failed:*`
- Heartbeat escalation/error → `heartbeat:escalated:*` / `heartbeat:error:*`
- Notification creation → `notification:created:*`
- Workflow completion → `workflow:completed:*`

**Triggers** listen for events via glob patterns and fire actions:

```
Pattern: "heartbeat:error:*"  →  Action: run skill "alert_admin"
Pattern: "task:failed:deploy" →  Action: prompt "The deploy failed. Investigate."
```

Triggers auto-disable after 5 consecutive failures for safety.

**Workflows** are multi-step pipelines with data passing between steps:

| Step Type | What It Does |
|---|---|
| `skill` | Runs a skill, stores result in context |
| `prompt` | Sends a message to Claude, gets a response |
| `condition` | Evaluates an expression, optionally skips to a step |
| `wait` | Pauses the workflow for a duration (creates a scheduled task to resume) |
| `approval` | Pauses workflow until a human approves or rejects |
| `notify` | Creates a notification |

Steps pass data via a JSON context hash using `{{context.step_name}}` interpolation:

```
Step 1 (skill: "check_status")    → result stored as context.check_status
Step 2 (prompt: "Status is {{context.check_status}}. What should we do?")
Step 3 (notify: "Action taken: {{context.step_2}}")
```

Workflows can auto-start on a trigger event or be kicked off immediately.

---

### Documents — Upload, Parse, and Generate Files

Documents let you attach files (PDF, CSV, Excel, plain text) to conversations. On upload, `DocumentParser` extracts the text content so the agent can read it without re-parsing. Token-efficient: parse once, read many times.

The agent can also create documents programmatically — generating reports, exports, or formatted files and attaching them to the conversation for download.

---

### Dynamic Data Tables — AI-Created Structured Storage

The agent can create real SQLite tables on the fly with custom schemas via `create_data_table`. Once created, full CRUD is available through `insert_data_record`, `update_data_record`, `delete_data_record`, and `query_data_table`.

Use cases: tracking lists, inventories, logs, or any structured data the agent needs to persist and query. Tables are first-class database objects — they support filtering, sorting, and aggregation via SQL.

---

### Approvals — Human-in-the-Loop Gates

Approvals pause automation until a human decides. They work standalone or as workflow steps (`approval` step type). Each approval has a title, description, and optional timeout with auto-expiry.

Events are emitted on decision: `approval:approved:*`, `approval:rejected:*`, `approval:expired:*` — so downstream triggers and workflows can react.

---

### Gmail Integration

Full OAuth2 Gmail integration with 6 dedicated tools: `gmail_search`, `gmail_read`, `gmail_send`, `gmail_draft`, `gmail_modify`, and `gmail_labels`. The agent can search your inbox, read messages, compose and send emails, manage drafts, and modify labels.

---

### Python Support

Run Python code alongside Ruby via `manage_python`. Includes virtualenv management for dependency isolation. Python skills are auto-discovered from `skills/` alongside Ruby skills.

---

### MCP Tools & Resources

Claude interacts with OpenFang through 38 MCP tools and 6 resources, served over SSE at `/mcp/sse`.

**Tools** (auto-discovered from `fang/tools/`):

| Tool | Purpose |
|---|---|
| **Core** | |
| `run_code` | Execute arbitrary Ruby with full model access |
| `run_skill` | Execute a saved skill by name |
| `manage_python` | Run Python code, manage virtualenv and dependencies |
| `send_message` | Send a message to the conversation |
| **Scheduling** | |
| `schedule_task` | Schedule a one-shot or recurring task |
| **Pages & Canvas** | |
| `create_page` | Create a new canvas page |
| `get_canvas` | Read current page's widget layout |
| `update_canvas` | Set page HTML content |
| `add_canvas_component` | Add a widget to the canvas |
| `update_canvas_component` | Modify a widget's position/content/data |
| `remove_canvas_component` | Remove a widget |
| `define_widget` | Create a new widget type (writes Ruby to disk) |
| **Documents** | |
| `create_document` | Upload or generate a document |
| `read_document` | Read extracted text from a document |
| `list_documents` | List documents in a conversation |
| **Data Tables** | |
| `create_data_table` | Create a dynamic SQLite table with custom schema |
| `list_data_tables` | List all dynamic data tables |
| `query_data_table` | Query records with filtering and sorting |
| `insert_data_record` | Insert a row into a data table |
| `update_data_record` | Update a row in a data table |
| `delete_data_record` | Delete a row from a data table |
| **Approvals** | |
| `create_approval` | Create a human-in-the-loop approval gate |
| `list_approvals` | List pending and resolved approvals |
| `resolve_approval` | Approve or reject a pending approval |
| **Automation** | |
| `create_notification` | Push a real-time notification |
| `create_trigger` | Set up an event-driven trigger |
| `create_workflow` | Build a multi-step automation pipeline |
| `create_heartbeat` | Set up a token-efficient monitor |
| `update_heartbeat` | Modify a heartbeat's config |
| `list_heartbeats` | View all heartbeats and their stats |
| **Web** | |
| `web_fetch` | HTTP requests (GET/POST/PUT/PATCH/DELETE) |
| `start_computer_use` | Launch a browser automation session |
| **Gmail** | |
| `gmail_search` | Search Gmail messages |
| `gmail_read` | Read a Gmail message by ID |
| `gmail_send` | Send an email via Gmail |
| `gmail_draft` | Create a Gmail draft |
| `gmail_modify` | Modify Gmail message labels (archive, star, etc.) |
| `gmail_labels` | List available Gmail labels |

**Resources** (context the agent can read):

| Resource | What It Provides |
|---|---|
| `config://user` | All config key/values, framework version |
| `conversation://current` | Current conversation context, last 10 messages |
| `skills://available` | All registered skills with usage counts |
| `database://schema` | Full schema: tables, columns, indexes, row counts |
| `gems://available` | All bundled gems and versions |
| `system://profile` | OS, hardware, disk, network, installed CLI tools, services |

**Auto-discovery**: Just create a file in `fang/tools/` that inherits `FastMcp::Tool` and restart. No registration code needed — `ObjectSpace` scanning handles it.

---

### Real-Time Web UI

The UI uses Turbo Streams over Server-Sent Events for instant updates. No WebSocket server, no Redis — just an in-memory pub/sub (`TurboBroadcast`) pushing HTML fragments to open SSE connections.

**What updates in real time:**
- Chat messages stream in as Claude generates them (thinking → tool use → text)
- Canvas widgets refresh when data changes
- Notifications appear instantly in the bell menu
- Heartbeat monitor updates after each run

**Canvas architecture:** The UI has a persistent chat footer at the bottom. Each canvas page can have multiple conversations. Tabs let you switch between canvases and conversations.

**Design system:** shadcn/ui-inspired with terminal green accent (`#22c55e`). Light/dark mode via `prefers-color-scheme`. Inter font, rounded corners, subtle shadows. Tailwind CSS via CDN with custom color tokens.

---

### WhatsApp Integration

Optional integration via GOWA (Go WhatsApp gateway). Inbound messages hit `/webhooks/whatsapp`, create a conversation with `source: 'whatsapp'`, and route through the same agent pipeline. Responses are sent back to the phone automatically.

---

## Quick Start

### Requirements

- Ruby 3.3+
- SQLite3 (or PostgreSQL)
- Claude Code CLI (`claude`) installed and authenticated

### Setup

```bash
git clone https://github.com/youruser/openfang.git
cd openfang
./setup.sh
```

### Authentication

OpenFang needs an Anthropic API key for the agent subprocess:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Running

```bash
./openfang.rb server        # Web UI on port 3000
./openfang.rb console       # IRB with all models loaded
./openfang.rb db:migrate    # Run pending migrations
./openfang.rb mcp           # MCP server standalone (port 9292)
```

Open `http://localhost:3000` and start chatting.

---

## Adding a Skill

Create `skills/my_skill.rb`:

```ruby
class MySkill < Fang::Skill
  description "What this skill does"
  param :name, :string, required: true, description: "Who to greet"

  def call(name:)
    send_message("Hello, #{name}!")
    { greeted: name }
  end
end
```

Restart the server. The skill is auto-discovered and available via `run_skill my_skill name: "World"`.

Or let Claude create skills for you — ask it to build something repeatable and it will write the skill file, register it, and use it going forward.

---

## Adding an MCP Tool

Create `fang/tools/my_tool.rb`:

```ruby
module Fang
  module Tools
    class MyTool < FastMcp::Tool
      tool_name 'my_tool'
      description 'What this tool does'

      arguments do
        required(:input).filled(:string).description('The input')
      end

      def call(input:)
        { success: true, result: input.upcase }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
```

Restart. Auto-discovered via `ObjectSpace`.

---

## Token Efficiency by Design

OpenFang is built around the idea that **AI should only be invoked when it's actually needed**.

| Pattern | How It Saves Tokens |
|---|---|
| **Skills** | Write code once, run it forever in pure Ruby. No AI round-trip for repeated operations. |
| **Heartbeats** | Skill runs every N seconds for free. AI is only invoked when the result is meaningful. |
| **Widgets** | Self-rendering Ruby classes. Once defined, they produce HTML without any AI involvement. |
| **Scheduled skill tasks** | Recurring cron tasks that run skills execute entirely in Ruby. |
| **`run_code`** | Claude writes Ruby that runs against the database directly — one tool call instead of multiple back-and-forth messages. |

The philosophy: Claude's job is to *build the automation*, not *be the automation*.

---

## License

MIT
