# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Canvas-First Architecture Refactor

## Context

The app has a thread exhaustion problem: each conversation tab opens its own SSE connection, and Puma threads are finite. The root cause is that conversations — not canvases — are the primary unit. This refactor makes **canvases the primary unit**, consolidates SSE to one connection per canvas, removes the `/conversations` index page, introduces a two-level tab bar, and adds URL-driven routing so every canvas an...

### Prompt 2

the chat about this should open a new conversation in the same canvas with the title (name of the widget) and some reference of the widget.

### Prompt 3

commit

