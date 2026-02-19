# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Gmail Integration — Ruby API + MCP Tools

## Context
Give OpenFang direct Gmail access so both the AI agent (via MCP tools) and Ruby skills/scheduled tasks can read, search, send, label, and manage emails without spending LLM tokens for routine operations.

## Approach
- `Fang::Clients::GmailClient < ApplicationClient` for HTTP calls (typed errors, logging, JSON parsing for free)
- `Fang::Gmail` module for OAuth lifecycle + high-level API (like `whatsapp.rb`)
-...

### Prompt 2

commit this

