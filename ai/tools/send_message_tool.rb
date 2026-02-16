# frozen_string_literal: true

module Ai
  module Tools
    class SendMessageTool
      include FastMcp::Tool

      tool_name 'send_message'
      description 'Send a message back to the user'

      parameter :content, type: 'string', description: 'Message content to send', required: true
      parameter :conversation_id, type: 'integer', description: 'Conversation ID (optional, defaults to current)', required: false

      def call(content:, conversation_id: nil)
        # Get conversation (from current context or provided ID)
        conversation = if conversation_id
          Conversation.find(conversation_id)
        else
          # TODO: Get from current context
          Conversation.last
        end

        unless conversation
          return {
            success: false,
            error: 'No conversation found'
          }
        end

        # Create assistant message
        message = conversation.add_message(
          role: 'assistant',
          content: content
        )

        Ai.logger.info "Message sent to conversation #{conversation.id}"

        {
          success: true,
          message_id: message.id,
          conversation_id: conversation.id,
          content: content
        }
      rescue => e
        Ai.logger.error "Failed to send message: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end
  end
end
