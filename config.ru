# frozen_string_literal: true

require_relative 'ai/bootstrap'

# Start the scheduler for recurring tasks
Ai::Scheduler.start!

# Configure MCP server (tools for the AI agent)
Ai::McpServer.configure!

if Ai.env == 'development'
  require 'rack/unreloader'

  Unreloader = Rack::Unreloader.new(subclasses: %w[Roda ActiveRecord::Base]) { Ai::Web::App }

  # Watch web app and views
  Unreloader.require File.expand_path('web/app.rb', __dir__)

  # Watch models for new ones created by the agent
  Dir[File.expand_path('ai/models/**/*.rb', __dir__)].each { |f| Unreloader.require f }

  # Mount MCP server as middleware, then the web app
  run Ai::McpServer.server.start_rack(Unreloader)
else
  require_relative 'web/app'
  run Ai::McpServer.server.start_rack(Ai::Web::App.freeze.app)
end
