# frozen_string_literal: true

module Ai
  class Notification < ActiveRecord::Base
    self.table_name = 'notifications'

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
      html = <<~HTML
        <turbo-stream action="prepend" target="notifications-list">
          <template>
            #{notification_card_html}
          </template>
        </turbo-stream>
        <turbo-stream action="replace" target="notifications-badge">
          <template>
            <span id="notifications-badge" class="badge badge-sm badge-primary">#{Notification.unread.count}</span>
          </template>
        </turbo-stream>
      HTML

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

    private

    def notification_card_html
      kind_badge = case kind
                   when 'success' then '<span class="badge badge-success badge-sm">success</span>'
                   when 'error'   then '<span class="badge badge-error badge-sm">error</span>'
                   when 'warning' then '<span class="badge badge-warning badge-sm">warning</span>'
                   else '<span class="badge badge-info badge-sm">info</span>'
                   end

      unread_class = status == 'unread' ? 'border-l-4 border-primary' : ''

      <<~HTML
        <div id="notification-#{id}" class="card bg-base-100 shadow-sm #{unread_class}">
          <div class="card-body p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <h3 class="font-semibold">#{ERB::Util.html_escape(title)}</h3>
                #{kind_badge}
              </div>
              <span class="text-xs text-base-content/50">#{created_at&.strftime('%b %d, %H:%M')}</span>
            </div>
            <p class="text-sm text-base-content/70 mt-1">#{ERB::Util.html_escape(body)}</p>
            <div class="card-actions justify-end mt-2">
              <form action="/notifications/#{id}/read" method="post" class="inline">
                <button type="submit" class="btn btn-ghost btn-xs">Mark Read</button>
              </form>
              <form action="/notifications/#{id}/chat" method="post" class="inline">
                <button type="submit" class="btn btn-primary btn-xs">Start Chat</button>
              </form>
            </div>
          </div>
        </div>
      HTML
    end
  end
end
