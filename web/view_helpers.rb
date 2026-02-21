# frozen_string_literal: true

require 'redcarpet'

module Fang
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
        details_html = is_user ? '' : render_message_metadata(message.metadata)

        <<~HTML
          <div class="#{msg_class}" id="message-#{message.id}">
            <div class="msg-meta flex items-center gap-2 mb-1">
              <span>#{label}</span>
              <time>#{time}</time>
            </div>
            <div class="prose-bubble">
              #{content}
            </div>
            #{details_html}
          </div>
        HTML
      end

      def render_message_metadata(metadata)
        return '' unless metadata.is_a?(Hash) && metadata.any?

        rows = []

        if metadata['model']
          # Show short model name (e.g. "claude-sonnet-4-..." → "sonnet-4")
          model_display = ERB::Util.html_escape(metadata['model'])
          rows << "<span>Model</span><span>#{model_display}</span>"
        end

        if metadata['num_turns']
          rows << "<span>Turns</span><span>#{metadata['num_turns']}</span>"
        end

        if metadata['total_cost_usd']
          cost = "$#{'%.4f' % metadata['total_cost_usd']}"
          rows << "<span>Cost</span><span>#{cost}</span>"
        end

        if (usage = metadata['usage']).is_a?(Hash)
          input = usage['input_tokens'] || usage['input']
          output = usage['output_tokens'] || usage['output']
          if input || output
            parts = []
            parts << "#{format_tokens(input)} in" if input
            parts << "#{format_tokens(output)} out" if output
            rows << "<span>Tokens</span><span>#{parts.join(' / ')}</span>"
          end

          cache_read = usage['cache_read_input_tokens'] || usage['cache_read']
          cache_create = usage['cache_creation_input_tokens'] || usage['cache_creation']
          if cache_read || cache_create
            cache_parts = []
            cache_parts << "#{format_tokens(cache_read)} read" if cache_read
            cache_parts << "#{format_tokens(cache_create)} created" if cache_create
            rows << "<span>Cache</span><span>#{cache_parts.join(' / ')}</span>"
          end
        end

        if metadata['thinking_steps'] && metadata['thinking_steps'] > 0
          rows << "<span>Thinking</span><span>#{metadata['thinking_steps']} block#{'s' if metadata['thinking_steps'] != 1}</span>"
        end

        if metadata['tool_calls'].is_a?(Array) && metadata['tool_calls'].any?
          names = metadata['tool_calls'].map { |t| t['name'] }.compact
          unique = names.tally.map { |n, c| c > 1 ? "#{n} (#{c}x)" : n }
          rows << "<span>Tools</span><span>#{ERB::Util.html_escape(unique.join(', '))}</span>"
        end

        if metadata['duration_ms']
          secs = metadata['duration_ms'] / 1000.0
          duration = secs >= 60 ? "#{(secs / 60).floor}m #{(secs % 60).round}s" : "#{'%.1f' % secs}s"
          rows << "<span>Duration</span><span>#{duration}</span>"
        end

        if metadata['session_id']
          short_id = metadata['session_id'].to_s[0..7]
          rows << "<span>Session</span><span title=\"#{ERB::Util.html_escape(metadata['session_id'])}\">#{short_id}</span>"
        end

        return '' if rows.empty?

        <<~HTML
          <details class="msg-details">
            <summary>Model info</summary>
            <div class="msg-details-grid">
              #{rows.join("\n              ")}
            </div>
          </details>
        HTML
      end

      def format_tokens(count)
        return '0' unless count
        count >= 1000 ? "#{'%.1f' % (count / 1000.0)}k" : count.to_s
      end

      def render_notification_card_html(notification)
        kind = badge_class(notification.kind)
        unread_class = notification.status == 'unread' ? ' notification-unread' : ''
        page = notification.page
        conversations = page ? page.conversations.recent.limit(5) : []

        canvas_label = page ? ERB::Util.html_escape(page.title) : 'No Canvas'

        submenu_items = conversations.map do |conv|
          conv_title = ERB::Util.html_escape(conv.title)
          %(<button type="button" class="notification-submenu-item" onclick="chatFooter.openCanvas(#{page.id}, '#{escape_js(page.title)}', '#{escape_js(page.slug)}', #{conv.id}, '#{escape_js(conv.title)}', '#{escape_js(conv.slug)}'); fetch('/notifications/#{notification.id}/read', {method:'POST'}); document.querySelector('.notifications-dropdown').style.display='none'"><span class="text-sm">#{conv_title}</span><span class="text-xs text-fang-muted-fg">#{conv.last_message_at&.strftime('%b %d, %H:%M')}</span></button>)
        end.join("\n")

        new_chat_button = %(<button type="button" class="notification-submenu-item notification-submenu-new" onclick="fetch('/notifications/#{notification.id}/chat', {method:'POST'}).then(r=>r.json()).then(d=>{chatFooter.openCanvas(d.page_id, d.page_title, d.page_slug, d.conversation_id, d.title, d.slug)}); document.querySelector('.notifications-dropdown').style.display='none'"><span class="text-sm font-medium">+ New Chat</span></button>)

        <<~HTML
          <div id="notification-#{notification.id}" class="card#{unread_class}">
            <div class="flex items-center justify-between mb-1">
              <div class="flex items-center gap-2 min-w-0">
                <span class="text-sm font-semibold truncate">#{ERB::Util.html_escape(notification.title)}</span>
                <span class="badge #{kind}">#{notification.kind || 'info'}</span>
              </div>
              <span class="text-xs text-fang-muted-fg shrink-0">#{notification.created_at&.strftime('%b %d, %H:%M')}</span>
            </div>
            #{"<p class=\"text-xs text-fang-muted-fg mt-0.5 line-clamp-2\">#{ERB::Util.html_escape(notification.body)}</p>" if notification.body.present?}
            <div class="flex items-center justify-between mt-2">
              <details class="notification-submenu">
                <summary class="xs outline">#{canvas_label}</summary>
                <div class="notification-submenu-panel">
                  #{"<div class=\"notification-submenu-section text-xs text-fang-muted-fg px-2 py-1\">Conversations</div>" if conversations.any?}
                  #{submenu_items}
                  #{"<div class=\"notification-submenu-divider\"></div>" if conversations.any?}
                  #{new_chat_button}
                </div>
              </details>
              #{"<button type=\"button\" class=\"ghost xs\" onclick=\"fetch('/notifications/#{notification.id}/read', {method:'POST'}); this.closest('.card').classList.remove('notification-unread'); this.remove()\">Mark Read</button>" if notification.status == 'unread'}
            </div>
          </div>
        HTML
      end

      def escape_js(str)
        str.to_s.gsub("'", "\\\\'").gsub("\n", "\\n")
      end
    end
  end
end
