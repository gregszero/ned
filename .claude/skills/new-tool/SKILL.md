# Create a New MCP Tool

Creates a new FastMcp::Tool that the AI agent (Ned) can use via MCP.

## Steps

1. Create the tool file at `ai/tools/<tool_name>_tool.rb`
2. Use this template:

```ruby
# frozen_string_literal: true

module Ai
  module Tools
    class <ToolName>Tool < FastMcp::Tool
      tool_name '<tool_name>'
      description '<What this tool does — be specific, the agent reads this>'

      arguments do
        required(:<arg>).filled(:string).description('<Argument description>')
        optional(:<opt>).filled(:string).description('<Optional argument>')
      end

      def call(<arg>:, <opt>: nil)
        # All Ai:: models are available here (Conversation, Message, AiPage, etc.)
        # Return a hash — the agent receives this as the tool result

        { success: true, result: 'done' }
      rescue => e
        Ai.logger.error "#{self.class.name} failed: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
```

3. **No registration needed** — tools are auto-discovered via ObjectSpace scanning in `ai/mcp_server.rb`
4. Restart the server (`./ai.rb server`) to pick up the new tool
5. Verify: `./ai.rb console` → check tool is listed

## Argument Types

FastMcp uses dry-schema. Common types:
- `.filled(:string)` — non-empty string
- `.filled(:integer)` — integer
- `.filled(:bool)` — boolean
- `.filled(:hash)` — hash/object
- `.filled(:array)` — array

## Broadcasting to UI

If your tool needs to push updates to the web UI in real-time:

```ruby
turbo_html = "<turbo-stream action=\"append\" target=\"some-target\"><template>#{html}</template></turbo-stream>"
Ai::Web::TurboBroadcast.broadcast('channel-name', turbo_html)
```

## Conventions

- File: `ai/tools/<snake_case>_tool.rb`
- Class: `Ai::Tools::<PascalCase>Tool`
- tool_name: `'snake_case'` (this is what the agent calls)
- Always return `{ success: true/false, ... }` hashes
- Log operations via `Ai.logger.info/error`
- Also update `workspace/CLAUDE.md` tool table so Ned knows about the new tool
