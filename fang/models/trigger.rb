# frozen_string_literal: true

module Fang
  class Trigger < ActiveRecord::Base
    self.table_name = 'triggers'

    # Validations
    validates :name, presence: true
    validates :event_pattern, presence: true
    validates :action_type, presence: true, inclusion: { in: %w[skill prompt] }

    # Scopes
    scope :enabled, -> { where(enabled: true) }

    def parsed_config
      return {} if action_config.blank?
      JSON.parse(action_config)
    rescue JSON::ParserError
      {}
    end

    def matches?(event_name)
      pattern = event_pattern.gsub('*', '.*')
      event_name.match?(/\A#{pattern}\z/)
    end

    def fire!(event_data = {})
      update!(fire_count: fire_count + 1, last_fired_at: Time.current, consecutive_failures: 0)
      config = parsed_config

      case action_type
      when 'skill'
        skill = SkillRecord.find_by!(name: config['skill_name'])
        params = (config['parameters'] || {}).symbolize_keys
        skill.load_and_execute(**params)
      when 'prompt'
        conversation = Conversation.create!(
          title: "Trigger: #{name}",
          source: 'scheduled_task'
        )
        message = conversation.add_message(
          role: 'user',
          content: config['prompt']
        )
        Jobs::AgentExecutorJob.perform_later(message.id)
        { conversation_id: conversation.id, message_id: message.id }
      end
    end

    def record_failure!
      increment!(:consecutive_failures)
      update!(enabled: false) if consecutive_failures >= 5
    end
  end
end
