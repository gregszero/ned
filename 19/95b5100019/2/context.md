# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Fix Agent Subprocess Error Handling

## Context

The Claude CLI subprocess (`fang/agent.rb`) produces garbled error messages like:
```
Agent error: Agent exited with code : {"level":"warn","message":"[BashTool] Pre-flight check is taking longer than expected..."}
```

Two bugs combine to produce this:

1. **Blank exit code**: `status.exitstatus` returns `nil` when the process is killed by a signal (e.g. timeout/SIGTERM). The code interpolates this nil directly, p...

### Prompt 2

commit this

