# frozen_string_literal: true

module Ai
  class Message < ActiveRecord::Base
    self.table_name = 'messages'

    # Associations
    belongs_to :conversation

    # Validations
    validates :content, presence: true
    validates :role, presence: true, inclusion: { in: %w[user assistant system] }

    # Scopes
    scope :by_role, ->(role) { where(role: role) }
    scope :user_messages, -> { where(role: 'user') }
    scope :assistant_messages, -> { where(role: 'assistant') }
    scope :system_messages, -> { where(role: 'system') }
    scope :chronological, -> { order(created_at: :asc) }

    # Callbacks
    before_create :set_defaults
    after_create :update_conversation_timestamp

    # Methods
    def user?
      role == 'user'
    end

    def assistant?
      role == 'assistant'
    end

    def system?
      role == 'system'
    end

    def truncated_content(length = 100)
      content.length > length ? "#{content[0...length]}..." : content
    end

    private

    def set_defaults
      self.metadata ||= {}
    end

    def update_conversation_timestamp
      conversation.touch(:last_message_at)
    end
  end
end
