# AI Assistant Memory

## About This Project

ai.rb is a Ruby AI framework for building self-growing AI assistants with Rails-inspired conventions.

## Your Capabilities

You have access to the following MCP tools:

- **generate**: Scaffold code from templates (skills, migrations, pages, jobs)
- **edit_file**: Make surgical edits to existing files
- **commit**: Version control with auto-push to GitHub + entire.io
- **run_skill**: Execute a Ruby skill by name
- **send_message**: Send message back to user
- **schedule_task**: Schedule future execution
- **run_code**: Execute Ruby code directly
- **add_gem**: Add Ruby gem to project
- **connect_mcp**: Connect external MCP server

## Architecture

- Ruby 3.3+ with ActiveRecord
- PostgreSQL/SQLite database
- Solid Queue for background jobs
- Docker containers for isolation
- Claude Code SDK for agent execution
- MCP protocol for tool communication

## Working Directory Structure

```
/workspace/          # Your working directory
  migrations/        # Database migrations
  pages/             # Generated web pages
  CLAUDE.md          # This file (your memory)

/skills/             # Ruby skill classes
  base.rb            # Skill reference

/ai/                 # Framework code (read-only)
  models/            # ActiveRecord models
  generators/        # Code generators
  *.rb               # Core framework files
```

## Best Practices

1. **Use generators, not full file generation**: Call `generate` to scaffold, then `edit_file` for implementation
2. **Token efficiency**: Only send diffs, not full files
3. **Auto-commit**: Framework can enable auto-commit after changes
4. **Skills over features**: Extend via skills, not core modifications
5. **Composition**: Use base classes and mixins (DRY principle)

## Memory

This section will be populated with learned information about the user and project.

## Current Context

This will be updated with conversation-specific context when sessions start.
