# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Add Scheduler Widget to Jobs & Skills Page

## Context
The Jobs & Skills canvas page currently shows scheduled tasks and skills but has no visibility into the Rufus scheduler's internal timers (the polling loops that drive the system). This widget will expose those timers so the user can see at a glance what's running, when it last fired, and when it fires next.

## Plan

### 1. Add `Fang::Scheduler.jobs` public method
**File:** `fang/scheduler.rb`

Add a public ...

### Prompt 2

commit this

