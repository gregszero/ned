# frozen_string_literal: true

module Ai
  module Jobs
    class WorkflowRunnerJob < ApplicationJob
      queue_as :workflows

      def perform(workflow_id)
        workflow = Workflow.find(workflow_id)
        return if workflow.completed? || workflow.failed?

        step = workflow.current_step
        return workflow.complete! unless step
        return if step.status == 'completed'

        workflow.update!(status: 'running') unless workflow.running?
        step.update!(status: 'running')

        result = step.execute!(workflow.parsed_context)

        step.update!(status: 'completed', result: result.to_json)
        workflow.merge_context!(step.name => result) if step.name.present?
        workflow.advance!

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Workflow not found: #{e.message}"
      rescue => e
        Ai.logger.error "Workflow step failed: #{e.message}"
        step&.update!(status: 'failed', result: { error: e.message }.to_json)
        workflow&.fail!(e.message)
      end
    end
  end
end
