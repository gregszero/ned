# frozen_string_literal: true

module Fang
  module Tools
    class UpdateHeartbeatTool < FastMcp::Tool
      tool_name 'update_heartbeat'
      description 'Update an existing heartbeat configuration'

      arguments do
        required(:name).filled(:string).description('Name of the heartbeat to update')
        optional(:frequency).filled(:integer).description('New frequency in seconds')
        optional(:description).filled(:string).description('New description')
        optional(:prompt_template).filled(:string).description('New prompt template')
        optional(:enabled).filled(:bool).description('Enable or disable the heartbeat')
        optional(:skill_name).filled(:string).description('New skill name')
      end

      def call(name:, **updates)
        heartbeat = Heartbeat.find_by(name: name)
        unless heartbeat
          return { success: false, error: "Heartbeat '#{name}' not found" }
        end

        updates.compact!

        # Validate new skill if changing
        if updates[:skill_name]
          unless SkillRecord.find_by(name: updates[:skill_name])
            return { success: false, error: "Skill '#{updates[:skill_name]}' not found" }
          end
        end

        # Reset error status when re-enabling
        if updates[:enabled] == true && heartbeat.error?
          updates[:status] = 'active'
        end

        # Set status based on enabled flag
        if updates.key?(:enabled)
          updates[:status] = updates[:enabled] ? 'active' : 'paused' unless updates[:status]
        end

        heartbeat.update!(**updates)

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
        Fang.logger.error "Failed to update heartbeat: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
