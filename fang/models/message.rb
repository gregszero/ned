# frozen_string_literal: true

module Fang
  class Message < ActiveRecord::Base
    self.table_name = 'messages'

    include HasJsonDefaults

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

    # Defaults
    json_defaults metadata: {}

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
  end
end
