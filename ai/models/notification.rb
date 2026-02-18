# frozen_string_literal: true

require_relative '../../web/view_helpers'

module Ai
  class Notification < ActiveRecord::Base
    self.table_name = 'notifications'

    include HasStatus
    include Web::ViewHelpers

    # Associations
    belongs_to :ai_page, class_name: 'Ai::AiPage', optional: true

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
      EventBus.emit("notification:created:#{kind}", { notification_id: id, title: title, kind: kind })
    end

    def start_conversation!
      page = ai_page || ensure_ai_page!

      conversation = Conversation.create!(
        title: title,
        source: 'web',
        ai_page_id: page.id
      )

      conversation.add_message(
        role: 'user',
        content: "Notification: #{title}\n\n#{body}"
      )

      update!(conversation_id: conversation.id)
      conversation
    end

    private

    def ensure_ai_page!
      page = AiPage.create!(
        title: title,
        content: '',
        status: 'published',
        published_at: Time.current
      )
      update!(ai_page_id: page.id)
      page
    end
  end
end
