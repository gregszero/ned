# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Canvas: Edit Lock + SVG Icon Toolbar

## Context
The canvas toolbar currently uses emoji icons (🔒🔓) and only has zoom percentage + scroll lock. We need to:
1. Add an "edit lock" toggle that disables drag and makes components behave like normal HTML
2. Replace all emoji icons in the toolbar with clean, minimal SVG icons (Figma-style)

## Changes

### 1. `web/public/js/controllers/canvas_controller.js`

**Add `editLocked` state** (similar to `scrollLock`):
- ...

### Prompt 2

commit this

