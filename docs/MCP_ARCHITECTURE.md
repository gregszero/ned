# MCP Architecture

## Philosophy

The OpenFang MCP server provides **framework integration**, not file manipulation. Claude Code already has excellent built-in capabilities for:

- Reading, editing, and creating files
- Running git commands
- Executing shell commands
- Managing the codebase

The MCP server focuses on what Claude Code **can't** do on its own: interacting with the running OpenFang framework.

## MCP Tools (4 total)

### 1. send_message
Send a message back to the user through the framework's message routing system.

**Use case**: AI wants to send a response to the user via the web UI or CLI.

```json
{
  "content": "Hello! I've completed your task.",
  "conversation_id": 123
}
```

### 2. run_skill
Execute a Ruby skill that's been registered in the database.

**Use case**: AI wants to run a previously created skill.

```json
{
  "skill_name": "send_email",
  "parameters": {
    "to": "user@example.com",
    "subject": "Test",
    "body": "Hello world"
  }
}
```

### 3. schedule_task
Schedule a task to run at a specific time via Solid Queue.

**Use case**: AI wants to schedule something for later execution.

```json
{
  "title": "Send reminder",
  "scheduled_for": "2 hours",
  "skill_name": "send_reminder",
  "parameters": { "message": "Don't forget!" }
}
```

### 4. run_code
Execute Ruby code in the framework's context with access to ActiveRecord models.

**Use case**: AI wants to query the database or run quick operations.

```json
{
  "ruby_code": "Conversation.count",
  "description": "Count total conversations"
}
```

## MCP Resources (5 total)

Resources provide **read-only** access to framework state.

### 1. config://user
User settings and configuration values.

Returns: User preferences, framework version, environment, etc.

### 2. conversation://current
Current conversation context and recent message history.

Returns: Conversation details, recent messages, active session info.

### 3. skills://available
List of all registered Ruby skills.

Returns: All skills with metadata, usage counts, and example structure.

### 4. database://schema
Current database schema with tables, columns, and indexes.

Returns: Complete database structure and row counts.

### 5. gems://available
Currently installed Ruby gems and versions.

Returns: All gems, Gemfile content, Ruby version.

## What Claude Code Handles Natively

- **File Operations**: Read, edit, create files directly
- **Git**: Run `git add`, `git commit`, `git push` commands
- **Gems**: Edit Gemfile, run `bundle install`
- **Migrations**: Create migration files, run `rake db:migrate`
- **Skills**: Create skill files in `skills/` directory
- **MCP Connections**: Create records directly via `run_code`

## Example Workflow

1. **User asks**: "Create a skill to send emails"

2. **Claude Code**:
   - Creates `skills/send_email.rb` file (native file creation)
   - Runs `run_code` to create SkillRecord in database
   - Runs `bundle install` to add `mail` gem if needed

3. **User asks**: "Send an email now"

4. **Claude Code**:
   - Calls `run_skill` tool with email parameters
   - Framework executes the skill
   - Uses `send_message` to confirm success

## Benefits of This Approach

1. **Simplicity**: No redundant tools
2. **Clarity**: Clear separation of concerns
3. **Efficiency**: Claude uses built-in capabilities where possible
4. **Focus**: MCP server does what only it can do
5. **Maintainability**: Fewer moving parts

## Starting the MCP Server

```bash
./openfang.rb mcp                    # Default: localhost:9292
./openfang.rb mcp --port 8080        # Custom port
./openfang.rb mcp --host 0.0.0.0     # Bind to all interfaces
```

## Container Integration

The agent container connects to the MCP server via:

```
MCP_URL=http://host.docker.internal:9292/mcp
```

Claude Code running in the container can then access all tools and resources.
