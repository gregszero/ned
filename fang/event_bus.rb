# frozen_string_literal: true

module Fang
  module EventBus
    def self.emit(event_name, data = {})
      Fang.logger.info "EventBus: #{event_name}"

      Trigger.where(enabled: true).find_each do |trigger|
        next unless trigger.matches?(event_name)
        Jobs::TriggerRunnerJob.perform_later(trigger.id, event_name, data.to_json)
      end

      # Auto-start workflows that listen for this event
      Workflow.where(trigger_event: event_name, status: 'pending').find_each do |workflow|
        workflow.update!(status: 'running')
        Jobs::WorkflowRunnerJob.perform_later(workflow.id)
      end
    end
  end
end
