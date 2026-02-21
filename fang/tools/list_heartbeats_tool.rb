# frozen_string_literal: true

module Fang
  module Tools
    class ListHeartbeatsTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'list_heartbeats'
      description 'List all heartbeats with their status and stats'
      tool_group :automation

      arguments do
        optional(:enabled_only).filled(:bool).description('Only show enabled heartbeats')
      end

      def call(enabled_only: false)
        heartbeats = enabled_only ? Heartbeat.enabled : Heartbeat.all
        heartbeats = heartbeats.order(:name)

        {
          success: true,
          heartbeats: heartbeats.map do |hb|
            {
              id: hb.id,
              name: hb.name,
              description: hb.description,
              skill_name: hb.skill_name,
              frequency: hb.frequency,
              frequency_label: hb.frequency_label,
              enabled: hb.enabled?,
              status: hb.status,
              run_count: hb.run_count,
              error_count: hb.error_count,
              last_run_at: hb.last_run_at&.iso8601,
              due_now: hb.due_now?
            }
          end,
          total: heartbeats.count
        }
      rescue => e
        Fang.logger.error "Failed to list heartbeats: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
