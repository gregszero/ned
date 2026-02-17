# frozen_string_literal: true

module Ai
  class ScheduledTask < ActiveRecord::Base
    self.table_name = 'scheduled_tasks'

    include HasStatus
    include HasJsonDefaults

    # Validations
    validates :title, presence: true
    validates :scheduled_for, presence: true
    validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

    # Statuses
    statuses :pending, :running, :completed, :failed
    scope :due, -> { where('scheduled_for <= ?', Time.current).where(status: 'pending') }
    scope :upcoming, -> { where('scheduled_for > ?', Time.current).where(status: 'pending') }

    # Defaults
    json_defaults parameters: {}

    # Methods
    def due?
      scheduled_for <= Time.current && pending?
    end

    def mark_running!
      update!(status: 'running')
    end

    def mark_completed!(result = nil)
      update!(status: 'completed', result: result)
    end

    def mark_failed!(error_message)
      update!(status: 'failed', result: error_message)
    end
  end
end
