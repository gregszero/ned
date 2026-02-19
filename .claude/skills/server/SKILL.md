# Run Server

Starts the OpenFang web server and guides you through using the web UI.

## What this does

Starts the Roda web application on port 3000 with:
- Conversation management
- Real-time message streaming (Turbo Streams)
- AI-generated pages
- Settings and configuration
- Beautiful dark theme UI

## When to use

Use this skill when you want to:
- Start the web UI
- Interact with AI via browser
- View conversations and messages
- Manage skills and MCP connections
- See AI-generated pages

## Usage

```bash
./openfang.rb server
```

Or with custom options:

```bash
./openfang.rb server --port 8080 --host 0.0.0.0
```

## What you need

- ✅ Setup complete (`./setup.sh` run successfully)
- ✅ Database migrated (17 tables exist)
- ✅ API key configured in `.env`
- ✅ Port 3000 available (or specify different port)

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

### Custom Host

```bash
./openfang.rb server --host 127.0.0.1
```

## Accessing the UI

Once started, open your browser:

```
http://localhost:3000
```

## Web UI Features

### 1. Conversations Page (`/conversations`)

**What you'll see:**
- List of all conversations
- Message counts and timestamps
- Source badges (web, cli)
- "New Conversation" button

**What you can do:**
- Click on a conversation to view messages
- Create new conversation
- See conversation metadata

### 2. Conversation View (`/conversations/:id`)

**What you'll see:**
- Message history (user and AI)
- Auto-scrolling messages
- Message timestamps
- Beautiful color-coded messages (blue for user, purple for AI)

**What you can do:**
- Send messages to AI
- View conversation history
- See real-time AI responses (Turbo Streams)

**How messaging works:**
1. Type message in textarea
2. Click "Send" or press Enter
3. Message saved to database
4. AgentExecutorJob enqueued (inline mode)
5. Docker container spawned for conversation
6. AI processes message via Claude Code SDK
7. Response streamed back in real-time
8. Message displayed in UI

### 3. Pages (`/pages`)

**What you'll see:**
- List of AI-generated pages
- Published pages only
- Publication dates

**What you can do:**
- View AI-created content
- Click to read full page
- See all published pages

### 4. Settings (`/settings`)

**What you'll see:**
- **Skills Section**: All registered Ruby skills with usage counts
- **MCP Connections**: External MCP servers configured
- **Configuration**: Framework version, Ruby version, environment, database, queue adapter

**What you can do:**
- View all skills and their metadata
- Check MCP connection status
- See framework configuration
- Monitor skill usage

### 5. Health Check (`/health`)

JSON endpoint:
```json
{
  "status": "ok",
  "timestamp": "2026-02-16T14:00:00Z"
}
```

## Workflow Example

**Creating your first conversation:**

1. **Start server**
   ```bash
   ./openfang.rb server
   ```

2. **Open browser**
   ```
   http://localhost:3000
   ```

3. **Create conversation**
   - Click "New Conversation" or fill in title
   - Click "Start New Conversation"

4. **Send message**
   - Type: "Hello! Can you help me?"
   - Click "Send"

5. **Watch AI respond**
   - Container spawns (first message takes ~3-5 seconds)
   - AI processes via Claude Code SDK
   - Response streams back in real-time
   - Message appears with purple background

6. **Continue conversation**
   - Send follow-up messages
   - Container stays alive for session
   - Fast responses after first message

## Behind the Scenes

When you send a message:

```
User types message
     ↓
POST /conversations/:id/messages
     ↓
Message saved to database
     ↓
AgentExecutorJob.perform_later(message_id)
     ↓
Job finds/spawns container
     ↓
Container runs Claude Code CLI
     ↓
Claude Code connects to MCP server
     ↓
MCP tools available: send_message, run_skill, schedule_task, run_code
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

## UI Theme

**Colors:**
- Background: Dark navy (`#0f172a`)
- Surface: Slate (`#1e293b`)
- Primary: Indigo (`#6366f1`)
- User messages: Blue (`#1e40af`)
- AI messages: Purple (`#7c3aed`)
- Text: Light gray (`#f1f5f9`)

**Features:**
- Smooth animations
- Auto-scrolling messages
- Responsive layout
- Modern card design
- Custom scrollbars
- Turbo Streams for real-time updates

## Stopping the Server

Press `Ctrl+C` in the terminal:

```
^C
- Gracefully stopping, waiting for requests to finish
=== puma shutdown: 2026-02-16 14:00:00 -0300 ===
- Goodbye!
```

## Running in Background

### Using tmux

```bash
# Start new tmux session
tmux new -s openfang

# Run server
./openfang.rb server

# Detach: Ctrl+B then D

# Reattach later
tmux attach -t openfang
```

### Using screen

```bash
# Start screen session
screen -S openfang

# Run server
./openfang.rb server

# Detach: Ctrl+A then D

# Reattach later
screen -r openfang
```

### Using Docker Compose

```bash
# Starts everything in background
docker-compose up -d

# View logs
docker-compose logs -f web

# Stop
docker-compose down
```

## Troubleshooting

**"Port 3000 already in use"**
```bash
# Find process using port
lsof -i :3000

# Kill process or use different port
./openfang.rb server --port 8080
```

**"Database not found"**
```bash
# Run migrations
bundle exec rake db:migrate
```

**"No conversations showing"**
```bash
# Create test data
./openfang.rb console
> Fang::Conversation.create!(title: "Test", source: "web")
```

**"Messages not sending"**
- Check `.env` has API key
- Check Docker daemon is running
- Check agent container built: `docker images | grep openfang-agent`

**"AI not responding"**
- Check API key is valid
- Check container logs: `docker ps` then `docker logs <container_id>`
- Check job execution: jobs run inline (synchronous)

## Production Deployment

### Using Docker Compose

```bash
# Production stack
docker-compose -f docker-compose.yml up -d
```

### Using Kamal

```bash
# First deployment
kamal setup

# Updates
kamal deploy
```

### Environment Variables

Production `.env`:
```bash
RAILS_ENV=production
DATABASE_URL=postgresql://user:pass@localhost/openfang_production
CLAUDE_CODE_OAUTH_TOKEN=your-token
```

## Monitoring

### Check Server Status

```bash
# Health check
curl http://localhost:3000/health

# JSON API
curl http://localhost:3000/api/conversations
```

### View Logs

Development:
```bash
# Server logs in terminal where you ran ./openfang.rb server
```

Production:
```bash
# Docker Compose
docker-compose logs -f web

# Kamal
kamal app logs
```

## Performance

**Typical response times:**
- Page load: ~50ms
- Message send: ~100ms (database write)
- First AI response: ~3-5 seconds (container spawn + AI processing)
- Follow-up responses: ~1-2 seconds (container warm)

**Resource usage:**
- Base: ~200MB RAM
- Per conversation: ~100MB RAM (container)
- Database: ~10MB (SQLite)

## Next Steps

After starting the server:

1. **Create conversations** - Chat with AI
2. **View settings** - Check skills, MCP connections
3. **Generate pages** - Ask AI to create pages
4. **Schedule tasks** - Ask AI to schedule future work
5. **Create skills** - Ask AI to generate Ruby skills

## Documentation

- Web UI styling: `web/public/css/style.css`
- Routes: `web/app.rb`
- Views: `web/views/`
- Layouts: `web/views/layout.erb`

**Server ready!** Open http://localhost:3000 and start chatting. 🚀
