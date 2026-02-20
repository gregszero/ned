# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Double-click to Edit Tab Names

## Context
The footer terminal has two rows of tabs (canvas tabs and conversation tabs). Currently tab names are static — clicking switches tabs, but there's no way to rename them. The user wants to double-click a tab title to edit it inline.

## Changes

### 1. Add PATCH API endpoints for renaming (`web/app.rb`)

**PATCH `/api/pages/:id`** — update page title (canvas tabs)
- Inside the existing `r.on 'api' do` > `r.on 'pages' ...

### Prompt 2

commit this

