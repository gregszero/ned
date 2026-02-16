# frozen_string_literal: true

require 'fast_mcp'

module Ai
  class McpServer
    class << self
      attr_accessor :server

      def configure!
        @server = FastMcp::Server.new(
          name: 'ai.rb',
          version: '0.1.0'
        )

        # Register tools
        register_tools

        # Register resources
        register_resources

        Ai.logger.info "MCP Server configured with #{@server.tools.count} tools and #{@server.resources.count} resources"
      end

      def start!(host: '0.0.0.0', port: 9292)
        configure! unless @server

        Ai.logger.info "Starting MCP server on #{host}:#{port}"

        # Start server (FastMCP will handle the web server)
        @server.run!(host: host, port: port)
      end

      private

      def register_tools
        # Load all tool files
        tool_files = Dir["#{Ai.root}/ai/tools/**/*.rb"].sort
        tool_files.each do |file|
          require file
        end

        # Tools will auto-register themselves via FastMCP
      end

      def register_resources
        # Load all resource files
        resource_files = Dir["#{Ai.root}/ai/resources/**/*.rb"].sort
        resource_files.each do |file|
          require file
        end

        # Resources will auto-register themselves via FastMCP
      end
    end
  end
end
