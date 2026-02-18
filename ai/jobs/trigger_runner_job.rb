# frozen_string_literal: true

module Ai
  module Jobs
    class TriggerRunnerJob < ApplicationJob
      queue_as :triggers

      def perform(trigger_id, event_name, event_data_json)
        trigger = Trigger.find(trigger_id)
        return unless trigger.enabled?

        event_data = JSON.parse(event_data_json) rescue {}
        Ai.logger.info "Firing trigger '#{trigger.name}' for event '#{event_name}'"

        trigger.fire!(event_data)

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Trigger not found: #{e.message}"
      rescue => e
        Ai.logger.error "Trigger '#{trigger&.name}' failed: #{e.message}"
        trigger&.record_failure!
      end
    end
  end
end
