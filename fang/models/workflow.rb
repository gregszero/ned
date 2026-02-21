# frozen_string_literal: true

module Fang
  class Workflow < ActiveRecord::Base
    self.table_name = 'workflows'

    include HasStatus

    # Associations
    belongs_to :conversation, optional: true
    has_many :workflow_steps, -> { order(:position) }, dependent: :destroy

    # Validations
    validates :name, presence: true
    validates :status, inclusion: { in: %w[pending running completed failed paused] }

    # Statuses
    statuses :pending, :running, :completed, :failed, :paused

    def current_step
      workflow_steps.find_by(position: current_step_index)
    end

    def parsed_context
      return {} if context.blank?
      JSON.parse(context)
    rescue JSON::ParserError
      {}
    end

    def merge_context!(data)
      update!(context: parsed_context.merge(data).to_json)
    end

    def advance!
      update!(current_step_index: current_step_index + 1)
      next_step = current_step
      if next_step
        Jobs::WorkflowRunnerJob.perform_later(id) unless %w[prompt wait approval].include?(next_step.step_type)
      else
        complete!
      end
    end

    def complete!
      update!(status: 'completed')
      EventBus.emit("workflow:completed:#{name.parameterize}", { workflow_id: id })
    end

    def fail!(error)
      update!(status: 'failed')
      EventBus.emit("workflow:failed:#{name.parameterize}", { workflow_id: id, error: error })
    end

    def pause!
      update!(status: 'paused')
    end

    def ensure_conversation!
      return conversation if conversation

      conv = Conversation.create!(
        title: "Workflow: #{name}",
        source: 'scheduled_task'
      )
      update!(conversation_id: conv.id)
      reload.conversation
    end
  end
end
