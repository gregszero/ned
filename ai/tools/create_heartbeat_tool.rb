# frozen_string_literal: true

module Ai
  module Tools
    class CreateHeartbeatTool < FastMcp::Tool
      tool_name 'create_heartbeat'
      description 'Create a new heartbeat that periodically runs a skill and escalates to AI when data is returned'

      arguments do
        required(:name).filled(:string).description('Unique name for the heartbeat')
        required(:skill_name).filled(:string).description('Name of the skill to run')
        optional(:frequency).filled(:integer).description('Seconds between runs (default: 300)')
        optional(:description).filled(:string).description('What this heartbeat monitors')
        optional(:prompt_template).filled(:string).description('AI prompt template with {{result}}, {{skill_name}}, {{name}} placeholders')
        optional(:enabled).filled(:bool).description('Whether to start enabled (default: true)')
      end

      def call(name:, skill_name:, frequency: 300, description: nil, prompt_template: nil, enabled: true)
        # Validate skill exists
        skill = SkillRecord.find_by(name: skill_name)
        unless skill
          return { success: false, error: "Skill '#{skill_name}' not found" }
        end

        # Auto-link to heartbeats canvas page
        page = AiPage.find_by(slug: 'heartbeats')

        heartbeat = Heartbeat.create!(
          name: name,
          skill_name: skill_name,
          frequency: frequency,
          description: description,
          prompt_template: prompt_template || "Heartbeat '{{name}}' ran skill '{{skill_name}}' and got this result:\n\n{{result}}\n\nPlease analyze and take appropriate action.",
          enabled: enabled,
          ai_page_id: page&.id,
          metadata: {}
        )

        {
          success: true,
          heartbeat: {
            id: heartbeat.id,
            name: heartbeat.name,
            skill_name: heartbeat.skill_name,
            frequency: heartbeat.frequency,
            frequency_label: heartbeat.frequency_label,
            enabled: heartbeat.enabled?,
            status: heartbeat.status
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.message }
      rescue => e
        Ai.logger.error "Failed to create heartbeat: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
