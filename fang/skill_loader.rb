# frozen_string_literal: true

module Fang
  class SkillLoader
    class << self
      # Load all skill files from skills/ directory
      def load_all
        skills_path = "#{Fang.root}/skills"
        return [] unless Dir.exist?(skills_path)

        # Load Ruby skills
        skill_files = Dir["#{skills_path}/**/*.rb"].reject { |f| f.include?('/base.rb') }

        skill_files.each do |file|
          load file
          Fang.logger.debug "Loaded skill: #{file}"
        end

        # Auto-sync Ruby SkillRecords from loaded skill files
        loaded_skills.each do |klass|
          name = skill_name_from_class(klass)
          file = skill_files.find { |f| f.include?("/#{name}.rb") }
          next unless file
          relative = file.sub("#{Fang.root}/", '')
          SkillRecord.find_or_create_by(name: name) do |r|
            r.file_path = relative
            r.class_name = klass.name
            r.language = 'ruby'
          end
        end

        # Discover and register Python skills
        python_files = Dir["#{skills_path}/**/*.py"]
        python_files.each do |file|
          name = File.basename(file, '.py')
          relative = file.sub("#{Fang.root}/", '')
          SkillRecord.find_or_create_by(name: name) do |r|
            r.file_path = relative
            r.language = 'python'
          end
          Fang.logger.debug "Registered Python skill: #{name}"
        end

        # Return list of loaded skill classes
        loaded_skills
      end

      # Reload all skills (useful in development)
      def reload!
        # Clear loaded skills
        Object.constants.grep(/Skill$/).each do |const|
          Object.send(:remove_const, const) rescue nil
        end

        load_all
      end

      # Run a skill by name
      def run(skill_name, **params)
        skill_class = find_skill(skill_name)

        unless skill_class
          raise ArgumentError, "Skill '#{skill_name}' not found. Available skills: #{available_skills.join(', ')}"
        end

        skill_instance = skill_class.new
        skill_instance.call(**params)
      end

      # List all available skills
      def available_skills
        loaded_skills.map { |klass| skill_name_from_class(klass) }
      end

      # Get skill metadata
      def skill_info(skill_name)
        skill_class = find_skill(skill_name)
        return nil unless skill_class

        {
          name: skill_name,
          class_name: skill_class.name,
          description: skill_class.description,
          parameters: skill_class.parameters
        }
      end

      private

      def loaded_skills
        ObjectSpace.each_object(Class).select { |klass| klass < Fang::Skill }
      end

      def find_skill(name)
        class_name = name.to_s.camelize
        Object.const_get(class_name) rescue nil
      end

      def skill_name_from_class(klass)
        klass.name.underscore
      end
    end
  end

  # Base class for all skills
  class Skill
    class << self
      attr_reader :parameters

      # DSL for defining skill description
      def description(text = nil)
        if text
          @description = text
        else
          @description
        end
      end

      # DSL for defining parameters
      def param(name, type, required: false, description: nil)
        @parameters ||= []
        @parameters << {
          name: name,
          type: type,
          required: required,
          description: description
        }
      end
    end

    # Built-in helper methods available to all skills
    def send_message(content, conversation_id: nil)
      conv_id = conversation_id || ENV['CONVERSATION_ID']
      return unless conv_id
      conversation = Fang::Conversation.find(conv_id)
      conversation.add_message(role: 'system', content: content)
    end

    def schedule_task(title:, scheduled_for:, skill_name: nil, parameters: {})
      Fang::ScheduledTask.create!(
        title: title,
        scheduled_for: scheduled_for,
        skill_name: skill_name,
        parameters: parameters
      )
    end

    def run_query(sql)
      ActiveRecord::Base.connection.execute(sql)
    end

    # Lifecycle hooks (can be overridden)
    def before_call; end
    def after_call; end
    def on_error(error); end

    # Main execution wrapper
    def execute(**params)
      before_call
      result = call(**params)
      after_call
      result
    rescue => e
      on_error(e)
      raise
    end

    # Must be implemented by subclasses
    def call(**params)
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end
  end
end
