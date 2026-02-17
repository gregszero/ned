# frozen_string_literal: true

module Ai
  module Resources
    class SkillsResource < FastMcp::Resource
      uri 'skills://available'
      resource_name 'Available Skills'
      description 'List of all available Ruby skills and their metadata'

      def content
        skills = SkillRecord.all.order(usage_count: :desc).map do |skill|
          {
            id: skill.id,
            name: skill.name,
            description: skill.description,
            file_path: skill.file_path,
            class_name: skill.class_name,
            usage_count: skill.usage_count,
            file_exists: skill.file_exists?,
            metadata: skill.metadata,
            created_at: skill.created_at
          }
        end

        {
          total_skills: skills.count,
          skills: skills,
          skill_directory: 'skills/',
          base_class: 'Ai::Skill',
          example: {
            name: 'example_skill',
            file_path: 'skills/example_skill.rb',
            structure: <<~RUBY
              class ExampleSkill < Ai::Skill
                description "What this skill does"

                param :name, :string, required: true

                def call(name:)
                  # Implementation
                  { success: true }
                end
              end
            RUBY
          }
        }.to_json
      end
    end
  end
end
