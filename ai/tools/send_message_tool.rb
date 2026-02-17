# frozen_string_literal: true

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
        else
          Conversation.last
        end

        unless conversation
          return { success: false, error: 'No conversation found' }
        end

        message = conversation.add_message(role: 'assistant', content: content)

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
    end
  end
end
