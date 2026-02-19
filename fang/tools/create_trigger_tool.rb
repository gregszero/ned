# frozen_string_literal: true

module Fang
  module Tools
    class CreateTriggerTool < FastMcp::Tool
      tool_name 'create_trigger'
      description 'Create an event trigger that fires a skill or prompt when a matching event occurs'

      arguments do
        required(:name).filled(:string).description('Trigger name')
        required(:event_pattern).filled(:string).description('Event pattern to match (e.g., "task:completed:*", "heartbeat:escalated:*")')
        required(:action_type).filled(:string).description('Action type: "skill" or "prompt"')
        required(:action_config).description('JSON config: { "skill_name": "...", "parameters": {} } for skill, or { "prompt": "..." } for prompt')
      end

      def call(name:, event_pattern:, action_type:, action_config:)
        config = action_config.is_a?(String) ? action_config : action_config.to_json

        trigger = Trigger.create!(
          name: name,
          event_pattern: event_pattern,
          action_type: action_type,
          action_config: config
        )

        {
          success: true,
          trigger_id: trigger.id,
          name: trigger.name,
          event_pattern: trigger.event_pattern,
          action_type: trigger.action_type
        }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
