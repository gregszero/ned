# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.3'

# Core framework
gem 'activerecord', '~> 8.0'
gem 'pg'                      # Database (PostgreSQL)
gem 'sqlite3'                 # SQLite option for development
gem 'rufus-scheduler'         # Cron-like recurring jobs
gem 'delayed_job'             # Persistent job queue
gem 'delayed_job_active_record' # ActiveRecord backend for delayed_job
gem 'solid_cable'             # WebSockets (for web UI)
gem 'solid_cache'             # Caching

# AI & MCP
gem 'fast-mcp'                # MCP server
gem 'anthropic'               # Anthropic API client

# CLI & Web
gem 'thor'                    # CLI interface
gem 'puma'                    # Web server
gem 'roda'                    # Lightweight web framework
gem 'tilt'                    # Template rendering
gem 'erubi'                   # ERB template engine
gem 'redcarpet'               # Markdown rendering

# Pagination
gem 'pagy'                    # Fast pagination

# Utilities (commonly needed)
gem 'httparty'                # HTTP client
gem 'nokogiri'                # HTML/XML parsing
gem 'dotenv'                  # Environment variables
gem 'json'                    # JSON support
gem 'pdf-reader'              # PDF text extraction
gem 'roo'                     # Excel/ODS parsing
gem 'marcel'                  # MIME type detection

group :development do
  gem 'pry'                   # Better console
  gem 'rake'                  # Task runner
  gem 'overcommit'            # Git hooks (push to GitHub + entire.io)
  gem 'rack-unreloader'       # Auto-reload code changes
end

group :test do
  gem 'webmock'                        # Stub HTTP for ApplicationClient tests
  gem 'database_cleaner-active_record' # Clean DB between tests
end
