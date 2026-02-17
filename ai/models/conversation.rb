# frozen_string_literal: true

module Ai
  class Conversation < ActiveRecord::Base
    self.table_name = 'conversations'

    include HasJsonDefaults

    # Associations
    has_many :messages, dependent: :destroy
    has_many :sessions, dependent: :destroy

    # Validations
    validates :source, presence: true, inclusion: { in: %w[web cli scheduled_task whatsapp] }

    # Scopes
    scope :recent, -> { order(last_message_at: :desc) }
    scope :by_source, ->(source) { where(source: source) }

    # Defaults
    json_defaults context: {}

    # Callbacks
    after_initialize :set_last_message_at, if: :new_record?

    # Methods
    def add_message(role:, content:, metadata: {})
      messages.create!(
        role: role,
        content: content,
        metadata: metadata
      ).tap do
        touch(:last_message_at)
      end
    end

    def active_session
      sessions.where(status: 'running').order(created_at: :desc).first
    end

    def latest_messages(limit = 10)
      messages.order(created_at: :desc).limit(limit).reverse
    end

    private

    def set_last_message_at
      self.last_message_at ||= Time.current
    end
  end
end
