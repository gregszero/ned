# frozen_string_literal: true

require 'fast_mcp'

module Fang
  class McpServer
    class << self
      attr_accessor :server

      def configure!
        @server = FastMcp::Server.new(
          name: 'ned',
          version: '0.1.0'
        )

        # Auto-discover and register tools/resources
        Dir["#{Fang.root}/fang/tools/**/*.rb"].sort.each { |f| require f }
        Dir["#{Fang.root}/fang/resources/**/*.rb"].sort.each { |f| require f }

        ObjectSpace.each_object(Class).select { |c| c < FastMcp::Tool }.each { |t| @server.register_tool(t) }
        ObjectSpace.each_object(Class).select { |c| c < FastMcp::Resource }.each { |r| @server.register_resource(r) }

        Fang.logger.info "MCP Server configured with #{@server.tools.count} tools and #{@server.resources.count} resources"
      end

      def start!(host: '0.0.0.0', port: 9292)
        configure! unless @server

        Fang.logger.info "Starting MCP server on #{host}:#{port}"
        @server.run!(host: host, port: port)
      end
    end
  end
end
