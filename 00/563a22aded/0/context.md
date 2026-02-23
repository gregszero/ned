# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Separate Ned repo with OpenFang as upstream

## Context
Ned currently clones the OpenFang repo directly. Agent-generated files on Ned (skills, pages, workspace data) will conflict with pulls from master. We want Ned to have its own GitHub repo (`gregszero/ned-openfang`) with the OpenFang repo as an upstream remote for pulling code updates.

## Steps

### 1. Create `gregszero/ned-openfang` repo on GitHub
```bash
gh repo create gregszero/ned-openfang --private --so...

### Prompt 2

commit this

