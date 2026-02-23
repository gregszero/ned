# Session Context

## User Prompts

### Prompt 1

Implement the following plan:

# Deploy OpenFang to Ned Server

## Context
OpenFang runs only on the local dev machine. We want it running permanently on the Ned server (Arch Linux, `100.99.225.5` via Tailscale) with PostgreSQL as the production database. We'll also add a deploy script to the codebase.

## Server Setup (on Ned via SSH)

### 1. Install system dependencies
```bash
sudo pacman -S --noconfirm base-devel postgresql postgresql-libs
gem install bundler
```

### 2. Setup PostgreSQL
```b...

### Prompt 2

shouldnt we run postgres with docker?

### Prompt 3

[Request interrupted by user for tool use]

### Prompt 4

why dont we use mise or smth else to handle versions?

