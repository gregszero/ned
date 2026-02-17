# frozen_string_literal: true

require 'fast_mcp'

module Ai
  class McpServer
    class << self
      attr_accessor :server

      def configure!
        @server = FastMcp::Server.new(
          name: 'ned',
          version: '0.1.0'
        )

        register_tools
        register_resources

        Ai.logger.info "MCP Server configured with #{@server.tools.count} tools and #{@server.resources.count} resources"
      end

      def start!(host: '0.0.0.0', port: 9292)
        configure! unless @server

        Ai.logger.info "Starting MCP server on #{host}:#{port}"
        @server.run!(host: host, port: port)
      end

      private

      def register_tools
        Dir["#{Ai.root}/ai/tools/**/*.rb"].sort.each { |f| require f }

        tool_classes.each { |tool| @server.register_tool(tool) }
      end

      def register_resources
        Dir["#{Ai.root}/ai/resources/**/*.rb"].sort.each { |f| require f }

        resource_classes.each { |resource| @server.register_resource(resource) }
      end

      def tool_classes
        [
          Ai::Tools::ScheduleTaskTool,
          Ai::Tools::SendMessageTool,
          Ai::Tools::RunSkillTool,
          Ai::Tools::RunCodeTool
        ]
      end

      def resource_classes
        [
          Ai::Resources::ConversationResource,
          Ai::Resources::DatabaseSchemaResource,
          Ai::Resources::AvailableGemsResource,
          Ai::Resources::ConfigResource,
          Ai::Resources::SkillsResource
        ]
      end
    end
  end
end
