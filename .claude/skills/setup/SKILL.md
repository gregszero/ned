# Setup OpenFang

Sets up the OpenFang Ruby AI framework from scratch.

## What this does

This skill guides you through the complete setup of OpenFang:

1. Checks dependencies (Ruby 3.3+, Docker, Git)
2. Installs Ruby gems
3. Sets up the database (SQLite by default)
4. Builds the AI agent Docker container
5. Creates necessary directories
6. Configures environment variables

## When to use

Use this skill when:
- Setting up OpenFang for the first time
- After cloning the repository
- When dependencies need to be verified

## Usage

```bash
# The setup script handles everything
./setup.sh
```

Or let Claude guide you through setup step by step.

## What you need

**Required:**
- Ruby 3.3 or higher
- Docker (for agent containers)
- Git (for version control)

**Optional:**
- PostgreSQL (for production, SQLite works for development)
- Claude Code OAuth token or Anthropic API key

## Steps

### 1. Check Dependencies

```bash
ruby --version   # Should be 3.3+
docker --version # Should be installed
git --version    # Should be installed
```

### 2. Install Gems

```bash
bundle install
```

This installs:
- ActiveRecord 8.x (database ORM)
- Solid Queue (background jobs)
- FastMCP (MCP server)
- Docker API (container management)
- Roda (web framework)
- And more...

### 3. Setup Database

```bash
bundle exec rake db:migrate
```

This creates all necessary tables:
- conversations, messages, sessions
- scheduled_tasks, skills, mcp_connections, config
- solid_queue_* tables
- pages

### 4. Build Agent Container

```bash
docker build -f container/Dockerfile -t openfang-agent .
```

This builds a container with:
- Ruby 3.3 Alpine
- Claude Code CLI (v2.1.42+)
- Common Ruby gems
- Workspace setup

### 5. Configure Environment

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and add ONE of these:

**Option 1 (Recommended):** Claude Code OAuth
```
CLAUDE_CODE_OAUTH_TOKEN=your-token-here
```

**Option 2 (Fallback):** Anthropic API Key
```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

Get your OAuth token:
```bash
claude auth status
```

### 6. Verify Setup

Test that everything works:

```bash
# Check CLI
./openfang.rb version

# Test database
./openfang.rb console
> Fang::Conversation.count
> exit

# Verify container
docker images | grep openfang-agent
```

## Quick Start After Setup

```bash
# Start web UI
./openfang.rb server

# Open browser
open http://localhost:3000

# Start MCP server (in another terminal)
./openfang.rb mcp
```

## Troubleshooting

**"Ruby not found"**
- Install Ruby 3.3+: `mise install ruby@3.3` or use rbenv/rvm

**"Docker not found"**
- Install Docker Desktop or Docker Engine

**"Bundle install fails"**
- Make sure you have build tools: `apt-get install build-essential`

**"Database migration fails"**
- Check `storage/` directory is writable
- Try: `rm storage/data.db && rake db:migrate`

**"Container build fails"**
- Check Docker daemon is running
- Try: `docker system prune` to free space

## What gets created

```
OpenFang/
├── storage/
│   ├── data.db          # SQLite database
│   └── sessions/        # Container sessions
├── .env                 # Your API keys
└── .git/                # Git repository
```

## Next Steps

After setup:

1. **Start the web UI**: `./openfang.rb server`
2. **Create a conversation**: Open http://localhost:3000
3. **Send a message**: AI will respond via container
4. **View settings**: Check skills, MCP connections, config
5. **Read docs**: Check FINAL_STATUS.md for full documentation

## WhatsApp Integration (Optional)

Connect OpenFang to WhatsApp using the Baileys bridge (like WhatsApp Web).

### Prerequisites

- Node.js 18+ installed (`node --version`)

### Setup Steps

1. Install bridge dependencies:
   ```bash
   cd whatsapp && npm install
   ```

2. Add to `.env`:
   ```
   WHATSAPP_ENABLED=true
   WHATSAPP_WEBHOOK_SECRET=your-random-secret-here
   ```
   Generate a secret: `ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"`

3. Start the bridge:
   ```bash
   ./openfang.rb whatsapp
   ```

4. Scan the QR code with WhatsApp > Linked Devices > Link a Device

5. **Alternative: Pairing code** (no QR needed):
   ```
   WHATSAPP_PAIRING_CODE=true
   WHATSAPP_PHONE_NUMBER=1234567890
   ```

6. Verify connection:
   ```ruby
   ./openfang.rb console
   > Fang::WhatsApp.status
   ```

Session persists in `whatsapp/auth/` — you only need to scan once.

## Advanced Setup

### PostgreSQL (Production)

1. Install PostgreSQL
2. Create database: `createdb openfang_production`
3. Update `.env`:
   ```
   DATABASE_URL=postgresql://user:pass@localhost/openfang_production
   ```

### Docker Compose

Full stack with PostgreSQL:

```bash
docker-compose up
```

This starts:
- PostgreSQL database
- Web UI (port 3000)
- MCP server (port 9292)

### Git Remotes

Configure version control:

```bash
# GitHub (primary)
git remote add origin https://github.com/youruser/OpenFang.git

# entire.io (mirror)
git remote add entire https://entire.io/youruser/OpenFang.git

# Push to both
git push origin master
git push entire master
```

## Success Criteria

Setup is complete when:

- ✅ `./openfang.rb version` shows version 0.1.0
- ✅ `./openfang.rb server` starts web UI on port 3000
- ✅ Database has 17 tables
- ✅ Docker image `openfang-agent` exists
- ✅ Web UI is accessible at http://localhost:3000

## Architecture Overview

**What you just set up:**

- **Web UI** (Roda) - Modern dark theme interface
- **Database** (SQLite/PostgreSQL) - 17 tables
- **Background Jobs** (Solid Queue) - 4 job classes
- **MCP Server** (FastMCP) - 4 tools + 5 resources
- **Container System** (Docker) - Isolated AI execution
- **CLI** (Thor) - 12 commands

## Documentation

- `README.md` - Quick start guide
- `FINAL_STATUS.md` - Complete implementation summary
- `docs/MCP_ARCHITECTURE.md` - MCP design philosophy
- `workspace/CLAUDE.md` - AI memory template

## Getting Help

If you encounter issues:

1. Check `./openfang.rb help` for available commands
2. Read `FINAL_STATUS.md` for detailed documentation
3. Review `docs/MCP_ARCHITECTURE.md` for architecture
4. Check GitHub issues: https://github.com/youruser/OpenFang/issues

**Setup complete!** The OpenFang framework is ready to use. 🎉
