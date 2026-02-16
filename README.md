# ai.rb

A Ruby AI framework for building self-growing AI assistants with Rails-inspired conventions.

## Philosophy

- **AI-native**: No installation wizard; Claude Code guides setup
- **Secure by isolation**: Agents run in containers with explicit mounts only
- **Customization = code changes**: No config sprawl; modify code directly
- **Skills over features**: Extend via skills, not core features
- **Generators over files**: AI uses generators, not full file creation (token efficient)

## Quick Start

```bash
git clone https://github.com/youruser/ai.rb.git
cd ai.rb
./setup.sh
```

Then open Claude Code and run `/setup` for guided configuration.

## Architecture

- **Ruby 3.3+**: Modern Ruby with ActiveRecord
- **PostgreSQL/SQLite**: Database (configurable)
- **Solid Queue**: Background jobs
- **Solid Cable**: WebSocket connections
- **Docker**: Container isolation for AI execution
- **Claude Code SDK**: AI agent execution environment
- **MCP Protocol**: Tool communication

## Project Structure

```
ai.rb/
├── ai/                 # Framework code
│   ├── models/         # ActiveRecord models
│   ├── generators/     # Code generators
│   └── *.rb            # Core framework files
├── skills/             # AI-generated Ruby skills
├── workspace/          # AI working directory
│   ├── migrations/     # Database migrations
│   └── pages/          # Generated pages
├── storage/            # Data storage
├── container/          # Docker configuration
├── config/             # Minimal configuration
└── web/                # Web UI

## Commands

```bash
./ai.rb chat              # Start CLI chat
./ai.rb server            # Start web UI (port 3000)
./ai.rb queue             # Start background worker
./ai.rb console           # Interactive console
./ai.rb db:migrate        # Run migrations
./ai.rb setup             # Initial setup
```

## Requirements

- Ruby 3.3+
- Docker
- PostgreSQL (or SQLite for development)

## Authentication

Supports two authentication methods:

1. **Claude Code OAuth** (recommended):
   ```bash
   export CLAUDE_CODE_OAUTH_TOKEN="your-token"
   ```

2. **Anthropic API Key** (fallback):
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```

## Deployment

Uses Kamal for one-command deployment:

```bash
kamal setup    # First time
kamal deploy   # Updates
```

## Contributing

Contribute skills, not features! Add new capabilities as skills in `skills/` directory.

## License

MIT
