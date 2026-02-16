# frozen_string_literal: true

module Ai
  class Session < ActiveRecord::Base
    self.table_name = 'sessions'

    # Associations
    belongs_to :conversation

    # Validations
    validates :status, presence: true, inclusion: { in: %w[starting running stopped error] }

    # Scopes
    scope :active, -> { where(status: 'running') }
    scope :stopped, -> { where(status: 'stopped') }
    scope :with_errors, -> { where(status: 'error') }

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
      update!(status: 'error', stopped_at: Time.current)
    end

    # container_id column repurposed as session_uuid
    def session_uuid
      container_id
    end

    def session_uuid=(value)
      self.container_id = value
    end
  end
end
