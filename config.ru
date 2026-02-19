# frozen_string_literal: true

require_relative 'fang/bootstrap'

# Start the scheduler for recurring tasks
Fang::Scheduler.start!

# Configure MCP server (tools for the AI agent)
Fang::McpServer.configure!

if Fang.env == 'development'
  require 'rack/unreloader'

  Unreloader = Rack::Unreloader.new(subclasses: %w[Roda ActiveRecord::Base]) { Fang::Web::App }

  # Watch web app and views
  Unreloader.require File.expand_path('web/app.rb', __dir__)

  # Watch models for new ones created by the agent
  Dir[File.expand_path('fang/models/**/*.rb', __dir__)].each { |f| Unreloader.require f }

  # Mount MCP server as middleware, then the web app
  run Fang::McpServer.server.start_rack(Unreloader)
else
  require_relative 'web/app'
  run Fang::McpServer.server.start_rack(Fang::Web::App.freeze.app)
end
