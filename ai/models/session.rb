# frozen_string_literal: true

module Ai
  class Session < ActiveRecord::Base
    self.table_name = 'sessions'

    # Associations
    belongs_to :conversation

    # Validations
    validates :status, presence: true, inclusion: { in: %w[starting running stopped error] }
    validates :container_id, uniqueness: true, allow_nil: true

    # Scopes
    scope :active, -> { where(status: 'running') }
    scope :stopped, -> { where(status: 'stopped') }
    scope :with_errors, -> { where(status: 'error') }
    scope :old, -> { where('stopped_at < ?', 30.minutes.ago) }

    # Methods
    def running?
      status == 'running'
    end

    def stopped?
      status == 'stopped'
    end

    def duration
      return nil unless started_at

      end_time = stopped_at || Time.current
      end_time - started_at
    end

    def start!
      update!(status: 'running', started_at: Time.current)
    end

    def stop!
      update!(status: 'stopped', stopped_at: Time.current)
    end

    def error!(message = nil)
      update!(
        status: 'error',
        stopped_at: Time.current
      )
    end
  end
end
