# Debug OpenFang

Troubleshooting guide for common issues.

## Check Server Status

```bash
# Is the server running?
curl -s http://localhost:3000/health | ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))'

# Check the process
pgrep -f "OpenFang server"
```

## Read Logs

The server logs to stdout. If running in foreground, logs appear in the terminal.

Common log patterns to look for:
- `[TurboBroadcast]` — SSE connection/broadcast events
- `[SSE]` — SSE stream open/close
- `Starting claude subprocess` — agent execution
- `MCP Server configured` — tool registration on boot

## Console Debugging

```bash
./openfang.rb console
```

Useful checks:
```ruby
# List registered MCP tools
ObjectSpace.each_object(Class).select { |c| c < FastMcp::Tool }.map(&:name)

# Check database
Fang::Conversation.count
Fang::Message.last
Fang::Page.published.pluck(:title, :slug)
Fang::Notification.unread.count
Fang::ScheduledTask.where('scheduled_for > ?', Time.current).count

# Test a tool manually
tool = Fang::Tools::CreatePageTool.new
tool.call(title: "Test Page", content: "<p>Hello</p>")

# Check if agent can find conversation
ENV['CONVERSATION_ID'] = '1'
Fang::Conversation.find_by(id: ENV['CONVERSATION_ID'])
```

## Common Errors

### "Session already in use"
The claude subprocess has a stale session lock. The agent auto-retries with `--resume`. If it persists:
```ruby
# In console
Fang::Session.where(status: 'running').update_all(status: 'stopped')
```

### "MCP connection failed"
The MCP server isn't running or the tool isn't registered.
```bash
# Check MCP config
cat workspace/.mcp.json

# Restart to re-register tools
./openfang.rb server
```

### "Tool not found" (agent hallucinating tools)
The agent is calling a tool that doesn't exist. Check `workspace/CLAUDE.md` — the "Your MCP Tools" table should only list real tools. Remove any references to non-existent tools.

### Messages not appearing in real-time
SSE stream may be disconnected. Check:
1. Browser console for EventSource errors
2. Server logs for `[SSE] Connection` messages
3. That `TurboBroadcast.broadcast` is being called (check tool code)

### Database migration fails
```bash
# Check current schema version
./openfang.rb console
ActiveRecord::Base.connection.migration_context.current_version

# Check pending migrations
ActiveRecord::Base.connection.migration_context.needs_migration?
```

## Verify SSE Streams

```bash
# Test conversation stream (replace 1 with conversation ID)
curl -N http://localhost:3000/conversations/1/stream

# Test notifications stream
curl -N http://localhost:3000/notifications/stream
```

You should see `: heartbeat` every 30 seconds if the connection is working.

## Key Files to Check

| Symptom | Check |
|---|---|
| Tools not loading | `fang/mcp_server.rb` — auto-discovery logic |
| Agent not responding | `fang/agent.rb` — subprocess execution |
| UI not updating | `web/turbo_broadcast.rb` — pub/sub |
| Routes broken | `web/app.rb` — Roda route tree |
| Models missing | `fang/bootstrap.rb` — auto-loading from `fang/models/` |
