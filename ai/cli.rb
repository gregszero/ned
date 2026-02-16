# frozen_string_literal: true

require 'thor'

module Ai
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "chat", "Start CLI chat interface"
    def chat
      require_relative 'chat'
      Ai::Chat.start
    end

    desc "server", "Start web UI server"
    option :port, type: :numeric, default: 3000, desc: "Port to run server on"
    option :host, type: :string, default: '0.0.0.0', desc: "Host to bind to"
    def server
      Ai.logger.info "Starting web server on #{options[:host]}:#{options[:port]}"

      # Use rackup with Puma
      exec "bundle exec puma config.ru -b tcp://#{options[:host]}:#{options[:port]}"
    end

    desc "queue", "Start Solid Queue worker"
    def queue
      require 'solid_queue/cli'
      SolidQueue::Cli.start(['start'])
    end

    desc "mcp", "Start MCP server"
    option :port, type: :numeric, default: 9292, desc: "Port to run MCP server on"
    option :host, type: :string, default: '0.0.0.0', desc: "Host to bind to"
    def mcp
      require_relative 'mcp_server'
      Ai::McpServer.start!(
        host: options[:host],
        port: options[:port]
      )
    end

    desc "console", "Start interactive console"
    def console
      require 'irb'
      ARGV.clear
      IRB.start
    end

    desc "db:migrate", "Run database migrations"
    def db_migrate
      Ai::Database.migrate!
      puts "✅ Database migrations complete"
    end

    desc "db:reset", "Drop and recreate database"
    def db_reset
      Ai::Database.reset!
      puts "✅ Database reset complete"
    end

    desc "db:seed", "Load seed data"
    def db_seed
      require_relative '../workspace/seeds' if File.exist?("#{Ai.root}/workspace/seeds.rb")
      puts "✅ Database seeded"
    end

    desc "setup", "Run initial setup"
    def setup
      require_relative 'setup'
      Ai::Setup.run
    end

    desc "version", "Show version information"
    def version
      puts "ai.rb version 0.1.0"
      puts "Ruby #{RUBY_VERSION}"
    end
  end
end
