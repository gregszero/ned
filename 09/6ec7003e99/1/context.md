# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Fix Scroll Lock to Be a True Canvas Mode + Route Settings/Jobs as Canvas Pages

## Context
The previous implementation made scroll-lock mode too aggressive — it converted components to `position: relative` flow layout, breaking the canvas metaphor entirely. The user wants:
- Settings and Jobs are **real canvas pages** with the full canvas+chat architecture (`/settings/chat_slug`)
- Scroll lock is just a **view mode toggle**: hides dots, replaces zoom-on-w...

### Prompt 2

commit

