# frozen_string_literal: true

require 'redcarpet'

module Ai
  module Tools
    class SendMessageTool < FastMcp::Tool
      tool_name 'send_message'
      description 'Send a message back to the user'

      arguments do
        required(:content).filled(:string).description('Message content to send')
        optional(:conversation_id).filled(:integer).description('Conversation ID (defaults to current)')
      end

      def call(content:, conversation_id: nil)
        conversation = if conversation_id
          Conversation.find(conversation_id)
        elsif ENV['CONVERSATION_ID']
          Conversation.find(ENV['CONVERSATION_ID'])
        else
          Conversation.last
        end

        unless conversation
          return { success: false, error: 'No conversation found' }
        end

        message = conversation.add_message(role: 'assistant', content: content)

        # Broadcast via TurboBroadcast so the message appears in the UI in real-time
        broadcast_message(conversation, message)

        Ai.logger.info "Message sent to conversation #{conversation.id}"

        {
          success: true,
          message_id: message.id,
          conversation_id: conversation.id
        }
      rescue => e
        Ai.logger.error "Failed to send message: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def broadcast_message(conversation, message)
        renderer = Redcarpet::Markdown.new(
          Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: '_blank', rel: 'noopener' }),
          fenced_code_blocks: true, tables: true, autolink: true, strikethrough: true, no_intra_emphasis: true
        )

        time = message.created_at.strftime('%I:%M %p')
        content_html = renderer.render(message.content)

        message_html = <<~HTML
          <div class="chat-msg ai" id="message-#{message.id}">
            <div class="msg-meta flex items-center gap-2 mb-1">
              <span>AI</span>
              <time>#{time}</time>
            </div>
            <div class="prose-bubble">
              #{content_html}
            </div>
          </div>
        HTML

        turbo_html = "<turbo-stream action=\"remove\" target=\"thinking-indicator-#{conversation.id}\"><template></template></turbo-stream>" \
                     "<turbo-stream action=\"append\" target=\"messages-#{conversation.id}\"><template>#{message_html}</template></turbo-stream>"
        Ai::Web::TurboBroadcast.broadcast(conversation.broadcast_channel, turbo_html)
      rescue => e
        Ai.logger.error "Failed to broadcast message: #{e.message}"
      end
    end
  end
end
