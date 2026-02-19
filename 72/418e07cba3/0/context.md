# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Data Table Widget — Implementation Plan

## Context

The existing `TableWidget` renders static columns/rows arrays with no pagination, filtering, or column configuration. The `ScheduledJobsWidget` hardcodes table HTML. Both patterns don't scale for larger datasets. This plan introduces a reusable `DataTableWidget` that auto-generates tables from any ActiveRecord model with server-side pagination (Pagy + Turbo Frame infinite scroll), sortable/resizable columns, ...

### Prompt 2

should update .claude files?

### Prompt 3

commit this

