# frozen_string_literal: true

module Fang
  module Tools
    class RunSkillTool < FastMcp::Tool
      tool_name 'run_skill'
      description 'Execute a Ruby skill by name'

      arguments do
        required(:skill_name).filled(:string).description('Name of the skill to run')
        optional(:parameters).filled(:hash).description('Parameters to pass to the skill')
      end

      def call(skill_name:, parameters: {})
        skill_record = SkillRecord.find_by(name: skill_name)

        unless skill_record
          return {
            success: false,
            error: "Skill '#{skill_name}' not found",
            available_skills: SkillRecord.pluck(:name)
          }
        end

        Fang.logger.info "Executing skill: #{skill_name} with params: #{parameters.inspect}"
        result = skill_record.load_and_execute(**parameters.transform_keys(&:to_sym))

        skill_record.increment_usage!

        {
          success: true,
          skill_name: skill_name,
          result: result,
          usage_count: skill_record.usage_count
        }
      rescue => e
        Fang.logger.error "Failed to execute skill #{skill_name}: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
