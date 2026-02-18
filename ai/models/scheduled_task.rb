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

    def recurring?
      recurring && cron_expression.present?
    end

    def schedule_next_run!
      return unless recurring?

      cron = Fugit::Cron.parse(cron_expression)
      return unless cron

      next_time = cron.next_time(Time.current).to_t

      self.class.create!(
        title: title,
        description: description,
        scheduled_for: next_time,
        skill_name: skill_name,
        parameters: parameters,
        cron_expression: cron_expression,
        recurring: true
      )

      update!(last_completed_at: Time.current)
    end
  end
end
