# Run Server

Starts the OpenFang web server and guides you through using the web UI.

## What this does

Starts the Roda web application on port 3000 with:
- Conversation management
- Real-time message streaming (Turbo Streams)
- AI-generated pages
- Settings and configuration

## When to use

Use this skill when you want to:
- Start the web UI
- Interact with AI via browser
- View conversations and messages
- Manage skills and MCP connections

## Usage

```bash
./openfang.rb server
```

Or with custom options:

```bash
./openfang.rb server --port 8080 --host 0.0.0.0
```

## What you need

- Setup complete (gems installed, database migrated)
- API key configured in `.env`
- Port 3000 available (or specify different port)

## Starting the Server

### Basic Start

```bash
./openfang.rb server
```

Expected output:
```
I, [date]  INFO -- : Connected to database: storage/data.db
Puma starting in single mode...
* Listening on http://0.0.0.0:3000
```

### Custom Port

```bash
./openfang.rb server --port 8080
```

## How Messaging Works

```
User types message
     ↓
POST /conversations/:id/messages
     ↓
Message saved to database
     ↓
AgentExecutorJob enqueued
     ↓
Claude Code CLI subprocess spawned
     ↓
Claude Code connects to MCP server
     ↓
MCP tools available (send_message, run_skill, etc.)
     ↓
AI responds via MCP send_message
     ↓
Response saved to database
     ↓
Turbo Stream updates UI
     ↓
User sees response
```

## Routes Available

- `GET /` - Redirects to conversations
- `GET /conversations` - List all conversations
- `POST /conversations` - Create new conversation
- `GET /conversations/:id` - View conversation
- `POST /conversations/:id/messages` - Send message
- `GET /pages` - List AI-generated pages
- `GET /pages/:slug` - View specific page
- `GET /settings` - Settings page
- `GET /health` - Health check
- `GET /api/conversations` - JSON API

## Running in Background

### Using tmux

```bash
tmux new -s openfang
./openfang.rb server
# Detach: Ctrl+B then D
# Reattach: tmux attach -t openfang
```

### Using systemd

Create a user service for persistent background running.

## Stopping the Server

Press `Ctrl+C` in the terminal.

## Troubleshooting

**"Port 3000 already in use"**
```bash
lsof -i :3000
# Kill process or use different port
./openfang.rb server --port 8080
```

**"Database not found"**
```bash
./openfang.rb db:migrate
```

**"Messages not sending"**
- Check `.env` has API key
- Check that Claude Code CLI is installed: `claude --version`

**"AI not responding"**
- Check API key is valid
- Check job execution in server logs
