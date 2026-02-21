# Setup OpenFang

Sets up the OpenFang Ruby AI framework from scratch.

## What this does

This skill guides you through the complete setup of OpenFang:

1. Checks dependencies (Ruby 3.3+, Git)
2. Installs Ruby gems
3. Sets up the database (SQLite)
4. Creates necessary directories
5. Configures environment variables

## When to use

Use this skill when:
- Setting up OpenFang for the first time
- After cloning the repository
- When dependencies need to be verified

## What you need

**Required:**
- Ruby 3.3 or higher
- Git (for version control)

**Optional:**
- Claude Code OAuth token or Anthropic API key

## Steps

### 1. Check Dependencies

```bash
ruby --version   # Should be 3.3+
git --version    # Should be installed
```

### 2. Install Gems

```bash
bundle install
```

### 3. Setup Database

```bash
./openfang.rb db:migrate
```

### 4. Configure Environment

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

### 5. Verify Setup

```bash
# Check CLI
./openfang.rb version

# Test database
./openfang.rb console
> Fang::Conversation.count
> exit
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

**"Bundle install fails"**
- Make sure you have build tools: `apt-get install build-essential`

**"Database migration fails"**
- Check `storage/` directory is writable
- Try: `rm storage/data.db && ./openfang.rb db:migrate`

## WhatsApp Integration (Optional)

Connect OpenFang to WhatsApp using the Baileys bridge.

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

3. Start the bridge:
   ```bash
   ./openfang.rb whatsapp
   ```

4. Scan the QR code with WhatsApp > Linked Devices > Link a Device

Session persists in `whatsapp/auth/` — you only need to scan once.

## Success Criteria

Setup is complete when:

- `./openfang.rb version` shows version
- `./openfang.rb server` starts web UI on port 3000
- Database is migrated
- Web UI is accessible at http://localhost:3000
