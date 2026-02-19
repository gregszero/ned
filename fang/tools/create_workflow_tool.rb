# frozen_string_literal: true

module Ai
  module Tools
    class CreateWorkflowTool < FastMcp::Tool
      tool_name 'create_workflow'
      description 'Create a multi-step workflow pipeline that executes steps in sequence'

      arguments do
        required(:name).filled(:string).description('Workflow name')
        optional(:description).filled(:string).description('Workflow description')
        required(:steps).description('Array of steps: [{ "name": "step1", "type": "skill|prompt|condition|wait|notify", "config": {} }]')
        optional(:trigger_event).filled(:string).description('Event that auto-starts this workflow')
      end

      def call(name:, steps:, description: nil, trigger_event: nil)
        workflow = Workflow.create!(
          name: name,
          description: description,
          trigger_event: trigger_event
        )

        steps.each_with_index do |step, i|
          config = step['config'] || step[:config] || {}
          WorkflowStep.create!(
            workflow: workflow,
            position: i,
            name: step['name'] || step[:name],
            step_type: step['type'] || step[:type],
            config: config.to_json
          )
        end

        # Start immediately if no trigger_event
        unless trigger_event
          workflow.update!(status: 'running')
          Jobs::WorkflowRunnerJob.perform_later(workflow.id)
        end

        {
          success: true,
          workflow_id: workflow.id,
          name: workflow.name,
          steps_count: workflow.workflow_steps.count,
          trigger_event: workflow.trigger_event,
          status: workflow.status
        }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
