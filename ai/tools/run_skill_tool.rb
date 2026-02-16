# frozen_string_literal: true

module Ai
  module Tools
    class RunSkillTool
      include FastMcp::Tool

      tool_name 'run_skill'
      description 'Execute a Ruby skill by name'

      parameter :skill_name, type: 'string', description: 'Name of the skill to run', required: true
      parameter :parameters, type: 'object', description: 'Parameters to pass to the skill', required: false

      def call(skill_name:, parameters: {})
        # Find skill in database
        skill_record = SkillRecord.find_by(name: skill_name)

        unless skill_record
          return {
            success: false,
            error: "Skill '#{skill_name}' not found",
            available_skills: SkillRecord.pluck(:name)
          }
        end

        # Execute skill
        Ai.logger.info "Executing skill: #{skill_name}"
        result = skill_record.load_and_execute(**(parameters || {}))

        # Increment usage count
        skill_record.increment_usage!

        {
          success: true,
          skill_name: skill_name,
          result: result,
          usage_count: skill_record.usage_count
        }
      rescue => e
        Ai.logger.error "Failed to execute skill #{skill_name}: #{e.message}"
        {
          success: false,
          error: e.message,
          backtrace: e.backtrace.first(5)
        }
      end
    end
  end
end
