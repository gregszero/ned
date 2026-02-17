# frozen_string_literal: true

module Ai
  module Web
    module ViewHelpers
      def badge_class(kind)
        case kind
        when 'success' then 'badge-success'
        when 'error'   then 'badge-error'
        when 'warning' then 'badge-warning'
        else 'badge-info'
        end
      end

      def turbo_stream(action, target, &block)
        content = block ? block.call : ''
        "<turbo-stream action=\"#{action}\" target=\"#{target}\"><template>#{content}</template></turbo-stream>"
      end

      def render_message_html(message)
        role_class = message.role == 'user' ? 'chat-end' : 'chat-start'
        bubble_class = message.role == 'user' ? 'chat-bubble-primary' : 'chat-bubble-secondary'
        label = message.role == 'user' ? 'You' : 'AI'
        time = message.created_at.strftime('%I:%M %p')
        content = ERB::Util.html_escape(message.content).gsub("\n", '<br>')

        <<~HTML
          <div class="chat #{role_class}" id="message-#{message.id}">
            <div class="chat-header text-xs text-base-content/50 mb-1">
              #{label}
              <time class="ml-1">#{time}</time>
            </div>
            <div class="chat-bubble #{bubble_class}">
              #{content}
            </div>
          </div>
        HTML
      end

      def render_notification_card_html(notification)
        kind_badge_class = badge_class(notification.kind)
        unread_class = notification.status == 'unread' ? 'border-l-4 border-primary' : ''

        <<~HTML
          <div id="notification-#{notification.id}" class="card bg-base-100 shadow-sm #{unread_class}">
            <div class="card-body p-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <h3 class="font-semibold">#{ERB::Util.html_escape(notification.title)}</h3>
                  <span class="badge #{kind_badge_class} badge-sm">#{notification.kind || 'info'}</span>
                </div>
                <span class="text-xs text-base-content/50">#{notification.created_at&.strftime('%b %d, %H:%M')}</span>
              </div>
              #{"<p class=\"text-sm text-base-content/70 mt-1\">#{ERB::Util.html_escape(notification.body)}</p>" if notification.body.present?}
              <div class="card-actions justify-end mt-2">
                #{"<form action=\"/notifications/#{notification.id}/read\" method=\"post\" class=\"inline\"><button type=\"submit\" class=\"btn btn-ghost btn-xs\">Mark Read</button></form>" if notification.status == 'unread'}
                <form action="/notifications/#{notification.id}/chat" method="post" class="inline">
                  <button type="submit" class="btn btn-primary btn-xs">Start Chat</button>
                </form>
              </div>
            </div>
          </div>
        HTML
      end
    end
  end
end
