# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Make OpenFang More Powerful for AI

## Context

Every agent invocation currently pays ~22K+ tokens of overhead before the AI even reads the user's message: ~15K for the monolithic system prompt (`workspace/CLAUDE.md`) + ~7K for 38 tool schemas. A simple "remind me at 5pm" loads Gmail patterns, canvas widget JSON examples, data table schemas, workflow pipeline docs, and 31 tools it will never use. Multi-widget dashboards require 5-6 sequential LLM turns for what s...

### Prompt 2

any test to add?

### Prompt 3

[Request interrupted by user for tool use]

