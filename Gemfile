# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.3'

# Core framework
gem 'activerecord', '~> 8.0'
gem 'pg'                      # Database (PostgreSQL)
gem 'sqlite3'                 # SQLite option for development
gem 'solid_queue'             # Background jobs
gem 'solid_cable'             # WebSockets (for web UI)
gem 'solid_cache'             # Caching

# AI & MCP
gem 'fast-mcp'                # MCP server
gem 'anthropic'               # Anthropic API client
gem 'docker-api'              # Container management

# CLI & Web
gem 'thor'                    # CLI interface
gem 'puma'                    # Web server
gem 'roda'                    # Lightweight web framework
gem 'tilt'                    # Template rendering
gem 'erubi'                   # ERB template engine

# Deployment
gem 'kamal', require: false   # Deployment

# Utilities (commonly needed)
gem 'httparty'                # HTTP client
gem 'nokogiri'                # HTML/XML parsing
gem 'dotenv'                  # Environment variables
gem 'json'                    # JSON support

group :development do
  gem 'pry'                   # Better console
  gem 'rake'                  # Task runner
  gem 'overcommit'            # Git hooks (push to GitHub + entire.io)
end
