# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Plan: SQLite WAL Mode + Persistent Job Queue

## Context

OpenFang runs Puma with 16-32 threads, all hitting SQLite. Without WAL mode, concurrent reads/writes can cause "database is locked" errors. Additionally, the ActiveJob `:async` adapter stores jobs in memory — any queued jobs (scheduled tasks, workflows, triggers) are lost on server restart. These two changes improve reliability with minimal complexity.

## Part 1: Enable SQLite WAL Mode

**File:** `fang/...

### Prompt 2

commit this

