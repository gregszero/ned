# frozen_string_literal: true

require_relative '../../web/view_helpers'

module Ai
  class Notification < ActiveRecord::Base
    self.table_name = 'notifications'

    include HasStatus
    include Web::ViewHelpers

    # Scopes
    scope :unread, -> { where(status: 'unread') }
    scope :recent, -> { order(created_at: :desc) }

    # Validations
    validates :title, presence: true
    validates :kind, inclusion: { in: %w[info success warning error], allow_nil: true }
    validates :status, inclusion: { in: %w[unread read dismissed] }

    def mark_read!
      update!(status: 'read')
    end

    def broadcast!
      card_html = render_notification_card_html(self)
      badge_html = %(<span id="notifications-badge" class="badge badge-sm badge-primary">#{Notification.unread.count}</span>)

      html = turbo_stream('prepend', 'notifications-list') { card_html } +
             turbo_stream('replace', 'notifications-badge') { badge_html }

      Web::TurboBroadcast.broadcast('notifications', html)
    end

    def start_conversation!
      conversation = Conversation.create!(
        title: title,
        source: 'web'
      )

      conversation.add_message(
        role: 'user',
        content: "Notification: #{title}\n\n#{body}"
      )

      update!(conversation_id: conversation.id)
      conversation
    end
  end
end
