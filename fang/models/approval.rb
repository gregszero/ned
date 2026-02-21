# frozen_string_literal: true

module Fang
  class Approval < ActiveRecord::Base
    self.table_name = 'approvals'

    include HasStatus

    belongs_to :workflow, optional: true
    belongs_to :workflow_step, optional: true
    belongs_to :notification, optional: true
    belongs_to :page, class_name: 'Fang::Page', optional: true

    validates :title, presence: true
    validates :status, inclusion: { in: %w[pending approved rejected expired] }

    statuses :pending, :approved, :rejected, :expired

    scope :recent, -> { order(created_at: :desc) }

    def parsed_metadata
      return {} if metadata.blank?
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end

    def approve!(notes: nil)
      update!(
        status: 'approved',
        decision_notes: notes,
        decided_at: Time.current
      )
      EventBus.emit("approval:approved:#{title.parameterize}", { approval_id: id, title: title })
      resume_workflow! if workflow
    end

    def reject!(notes: nil)
      update!(
        status: 'rejected',
        decision_notes: notes,
        decided_at: Time.current
      )
      EventBus.emit("approval:rejected:#{title.parameterize}", { approval_id: id, title: title })
      workflow&.fail!("Approval rejected: #{title}")
    end

    def expire!
      return unless pending?

      update!(
        status: 'expired',
        decided_at: Time.current
      )
      EventBus.emit("approval:expired:#{title.parameterize}", { approval_id: id, title: title })
      workflow&.fail!("Approval expired: #{title}")
    end

    private

    def resume_workflow!
      return unless workflow&.paused?

      step = workflow_step || workflow.current_step
      step&.update!(status: 'completed')
      workflow.update!(status: 'running')
      workflow.merge_context!({ step&.name => { approved: true, notes: decision_notes } })
      workflow.advance!
    end
  end
end
