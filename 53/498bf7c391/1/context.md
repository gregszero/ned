# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Add GitHub Actions CI

## Context
OpenFang now has a test suite (169 Ruby tests + 24 Python tests) but no CI pipeline. Adding a GitHub Actions workflow ensures tests run on every push and PR.

## Plan

### Create `.github/workflows/ci.yml`

Single workflow file with two parallel jobs:

**Ruby tests job:**
- Ubuntu latest
- Ruby 3.3 (matches Gemfile `~> 3.3` — use stable 3.3 rather than bleeding-edge 3.4 which has bundled gem issues)
- `ruby/setup-ruby` with `bu...

### Prompt 2

commit this

