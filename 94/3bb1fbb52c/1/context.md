# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: Test for `scrape_website` MCP Tool

## Context

The `scrape_website` tool (`fang/tools/scrape_website_tool.rb`) was just implemented. It delegates to `PythonRunner` to run scrapling-based Python code. We need a test file covering the key behaviors, stubbing `PythonRunner` to avoid real network/Python calls.

## File to Create

**`test/tools/scrape_website_tool_test.rb`**

## Test Cases

Following the existing `ToolTestCase` pattern (see `test/tools/run_code...

### Prompt 2

commit this

