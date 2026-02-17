# frozen_string_literal: true

require 'redcarpet'

module Ai
  module Web
    module ViewHelpers
      def badge_class(kind)
        case kind
        when 'success' then 'success'
        when 'error'   then 'error'
        when 'warning' then 'warning'
        else 'info'
        end
      end

      def turbo_stream(action, target, &block)
        content = block ? block.call : ''
        "<turbo-stream action=\"#{action}\" target=\"#{target}\"><template>#{content}</template></turbo-stream>"
      end

      def markdown_renderer
        @markdown_renderer ||= Redcarpet::Markdown.new(
          Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: '_blank', rel: 'noopener' }),
          fenced_code_blocks: true,
          tables: true,
          autolink: true,
          strikethrough: true,
          no_intra_emphasis: true
        )
      end

      def render_markdown(text)
        markdown_renderer.render(text)
      end

      def render_message_html(message)
        is_user = message.role == 'user'
        msg_class = is_user ? 'chat-msg user' : 'chat-msg ai'
        label = is_user ? 'YOU' : 'AI'
        time = message.created_at.strftime('%I:%M %p')
        content = render_markdown(message.content)

        <<~HTML
          <div class="#{msg_class}" id="message-#{message.id}">
            <div class="flex items-center gap-2 mb-1" style="font-size:0.65rem;text-transform:uppercase;letter-spacing:0.1em;opacity:0.6;">
              <span>#{label}</span>
              <time>#{time}</time>
            </div>
            <div class="prose-bubble">
              #{content}
            </div>
          </div>
        HTML
      end

      def render_notification_card_html(notification)
        kind = badge_class(notification.kind)
        unread_border = notification.status == 'unread' ? 'border-left:4px solid var(--ned-accent);' : ''

        <<~HTML
          <div id="notification-#{notification.id}" class="card" style="#{unread_border}">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <h3 style="font-weight:600;font-size:1rem;text-transform:none;">#{ERB::Util.html_escape(notification.title)}</h3>
                <span class="badge #{kind}">#{notification.kind || 'info'}</span>
              </div>
              <span style="font-size:0.75rem;color:var(--ned-muted-fg);">#{notification.created_at&.strftime('%b %d, %H:%M')}</span>
            </div>
            #{"<p style=\"font-size:0.875rem;color:var(--ned-muted-fg);margin-top:0.25rem;\">#{ERB::Util.html_escape(notification.body)}</p>" if notification.body.present?}
            <div class="flex justify-end gap-2 mt-3">
              #{"<form action=\"/notifications/#{notification.id}/read\" method=\"post\" style=\"display:inline;\"><button type=\"submit\" class=\"ghost xs\">Mark Read</button></form>" if notification.status == 'unread'}
              <form action="/notifications/#{notification.id}/chat" method="post" style="display:inline;">
                <button type="submit" class="xs">Start Chat</button>
              </form>
            </div>
          </div>
        HTML
      end
    end
  end
end
