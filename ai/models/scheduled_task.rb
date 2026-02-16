# frozen_string_literal: true

module Ai
  class ScheduledTask < ActiveRecord::Base
    self.table_name = 'scheduled_tasks'

    # Validations
    validates :title, presence: true
    validates :scheduled_for, presence: true
    validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

    # Scopes
    scope :pending, -> { where(status: 'pending') }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :due, -> { where('scheduled_for <= ?', Time.current).where(status: 'pending') }
    scope :upcoming, -> { where('scheduled_for > ?', Time.current).where(status: 'pending') }

    # Callbacks
    before_create :set_defaults

    # Methods
    def due?
      scheduled_for <= Time.current && pending?
    end

    def pending?
      status == 'pending'
    end

    def completed?
      status == 'completed'
    end

    def failed?
      status == 'failed'
    end

    def mark_running!
      update!(status: 'running')
    end

    def mark_completed!(result = nil)
      update!(
        status: 'completed',
        result: result
      )
    end

    def mark_failed!(error_message)
      update!(
        status: 'failed',
        result: error_message
      )
    end

    private

    def set_defaults
      self.parameters ||= {}
    end
  end
end
