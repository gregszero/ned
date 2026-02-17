# ai.rb — Claude Code Guide

## What This Is

A personal AI assistant framework ("Ned") built in Ruby. It combines a Roda web UI, ActiveRecord models (SQLite), FastMCP tool server, and a Claude Code CLI subprocess as the agent runtime.

## Architecture

```
ai.rb (entrypoint) → Ai::CLI (Thor)
├── web/app.rb          Roda web server (port 3000)
├── ai/mcp_server.rb    FastMCP tool server (port 9292)
├── ai/agent.rb         Spawns `claude` CLI subprocess per conversation
├── ai/bootstrap.rb     Loads everything, connects DB
└── ai/scheduler.rb     Rufus-scheduler for recurring tasks
```

**Real-time updates**: In-memory pub/sub (`web/turbo_broadcast.rb`) → SSE → Turbo Streams in the browser. No ActionCable or Redis needed — everything runs in one process.

**Agent execution**: When a user sends a message, `AgentExecutorJob` runs `Ai::Agent.execute`, which spawns a `claude` CLI subprocess with MCP tools. The subprocess uses `workspace/.mcp.json` and `workspace/CLAUDE.md` as its system prompt.

## Key Conventions

- **Auto-discovery via ObjectSpace**: MCP tools (`ai/tools/`) and resources (`ai/resources/`) are auto-registered by scanning for subclasses of `FastMcp::Tool` and `FastMcp::Resource`. Just create the file — no manual registration needed.
- **No index pages for content types**: When the AI creates a new page/content type, add a direct link to it in the nav bar (`web/views/layout.erb`) instead of creating a separate listing page. Each page is served at `/pages/:slug`.
- **Models use concerns**: Shared behavior lives in `ai/concerns/` (e.g., `HasStatus`).

## Running the App

```bash
./ai.rb server        # Start web UI on port 3000
./ai.rb console       # IRB with all models loaded
./ai.rb db:migrate    # Run pending migrations
./ai.rb mcp           # Start MCP server standalone
```

## Adding a New MCP Tool

1. Create `ai/tools/my_tool.rb`:

```ruby
# frozen_string_literal: true

module Ai
  module Tools
    class MyTool < FastMcp::Tool
      tool_name 'my_tool'
      description 'What this tool does'

      arguments do
        required(:name).filled(:string).description('Argument description')
        optional(:option).filled(:string).description('Optional argument')
      end

      def call(name:, option: nil)
        # Tool logic here — all Ai:: models are available
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

2. Create model in `ai/models/thing.rb`:

```ruby
module Ai
  class Thing < ActiveRecord::Base
    self.table_name = 'things'
  end
end
```

3. Run `./ai.rb db:migrate`

## Design System

Clean, minimal shadcn/ui-inspired design with violet accent. Supports light/dark mode via `prefers-color-scheme`. Inter font, rounded corners, subtle shadows.

### CSS Tokens (defined in `web/public/css/style.css`)

Light and dark mode tokens are defined as CSS custom properties. The `--ned-*` aliases remain for backward compatibility with Tailwind classes.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `--background` | `#ffffff` | `#09090b` | Page background |
| `--foreground` | `#0f172a` | `#fafafa` | Primary text |
| `--card` | `#ffffff` | `#18181b` | Card backgrounds |
| `--muted` | `#f1f5f9` | `#27272a` | Muted backgrounds |
| `--muted-foreground` | `#64748b` | `#a1a1aa` | Muted text |
| `--primary` | `#7c3aed` | `#8b5cf6` | Accent (violet) |
| `--primary-foreground` | `#ffffff` | `#ffffff` | Text on accent |
| `--border` | `#e2e8f0` | `#27272a` | Borders |
| `--ring` | `#7c3aed` | `#8b5cf6` | Focus rings |

### Components
- **`.card`** — rounded card with subtle border and shadow
- **`.badge`** — pill label (variants: `.success`, `.error`, `.warning`, `.info`)
- **`button`** — violet bg, rounded. Variants: `.ghost`, `.outline`, `.sm`, `.xs`, `.icon`
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

Tailwind CSS is loaded via CDN with custom colors: `ned-bg`, `ned-fg`, `ned-muted`, `ned-muted-fg`, `ned-accent`, `ned-accent-fg`, `ned-border`, `ned-card`, `ned-primary`, `ned-ring`.

## Key Files

| File | Purpose |
|---|---|
| `ai.rb` | CLI entrypoint |
| `ai/bootstrap.rb` | Framework loader |
| `ai/agent.rb` | Claude subprocess execution |
| `ai/mcp_server.rb` | FastMCP tool/resource registration |
| `web/app.rb` | All Roda routes |
| `web/views/layout.erb` | Main layout with sidebar nav |
| `web/view_helpers.rb` | HTML rendering helpers (turbo_stream, markdown, message/notification cards) |
| `web/turbo_broadcast.rb` | In-memory pub/sub for SSE |
| `web/public/css/style.css` | Complete design system |
| `workspace/CLAUDE.md` | Ned's system prompt (the inner agent reads this) |
| `workspace/.mcp.json` | MCP config passed to claude subprocess |

## Existing MCP Tools

| Tool | File | Purpose |
|---|---|---|
| `run_code` | `ai/tools/run_code_tool.rb` | Execute Ruby code with model access |
| `run_skill` | `ai/tools/run_skill_tool.rb` | Execute saved skills by name |
| `send_message` | `ai/tools/send_message_tool.rb` | Send message + broadcast via SSE |
| `schedule_task` | `ai/tools/schedule_task_tool.rb` | Schedule future tasks/reminders |
| `create_page` | `ai/tools/create_page_tool.rb` | Create AiPage (appears in nav) |
| `create_notification` | `ai/tools/create_notification_tool.rb` | Create + broadcast notification |
