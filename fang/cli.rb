# frozen_string_literal: true

require 'thor'

module Fang
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "chat", "Start CLI chat interface"
    def chat
      require_relative 'chat'
      Fang::Chat.start
    end

    desc "server", "Start web UI server"
    option :port, type: :numeric, default: 3000, desc: "Port to run server on"
    option :host, type: :string, default: '0.0.0.0', desc: "Host to bind to"
    def server
      Fang.logger.info "Starting web server on #{options[:host]}:#{options[:port]}"

      # Use rackup with Puma
      exec "bundle exec puma config.ru -b tcp://#{options[:host]}:#{options[:port]} -w 0 -t 16:32"
    end

    desc "mcp", "Start MCP server"
    option :port, type: :numeric, default: 9292, desc: "Port to run MCP server on"
    option :host, type: :string, default: '0.0.0.0', desc: "Host to bind to"
    def mcp
      require_relative 'mcp_server'
      Fang::McpServer.start!(
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
      Fang::Database.migrate!
      puts "✅ Database migrations complete"
    end

    desc "db:reset", "Drop and recreate database"
    def db_reset
      Fang::Database.reset!
      puts "✅ Database reset complete"
    end

    desc "db:seed", "Load seed data"
    def db_seed
      require_relative '../workspace/seeds' if File.exist?("#{Fang.root}/workspace/seeds.rb")
      puts "✅ Database seeded"
    end

    desc "setup", "Run initial setup"
    def setup
      require_relative 'setup'
      Fang::Setup.run
    end

    desc "gmail:auth", "Authenticate with Gmail via OAuth"
    def gmail_auth
      unless Fang::Gmail.enabled?
        puts "Gmail not configured. Add GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET to .env"
        exit 1
      end

      require 'socket'

      url = Fang::Gmail.authorization_url
      puts "Opening browser for Gmail authorization..."
      puts url
      system("xdg-open '#{url}' 2>/dev/null || open '#{url}' 2>/dev/null &")

      server = TCPServer.new('127.0.0.1', 8484)
      puts "Waiting for OAuth callback on http://127.0.0.1:8484 ..."

      client = server.accept
      request_line = client.gets
      code = request_line[/code=([^&\s]+)/, 1]

      if code
        Fang::Gmail.exchange_code!(code)
        client.print "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" \
                     "<h1>Gmail authenticated!</h1><p>You can close this tab.</p>"
        puts "Gmail authenticated successfully!"
      else
        client.print "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html\r\n\r\n" \
                     "<h1>Authentication failed</h1><p>No authorization code received.</p>"
        puts "Authentication failed — no authorization code received."
      end

      client.close
      server.close
    end

    desc "version", "Show version information"
    def version
      puts "openfang version 0.1.0"
      puts "Ruby #{RUBY_VERSION}"
    end
  end
end
