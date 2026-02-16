# frozen_string_literal: true

module Ai
  class MessageRouter
    class << self
      # Route a message to the appropriate handler based on source
      def route(message, source: 'web')
        case source
        when 'web'
          handle_web_message(message)
        when 'cli'
          handle_cli_message(message)
        when 'whatsapp'
          handle_whatsapp_message(message)
        else
          Ai.logger.warn "Unknown message source: #{source}"
        end
      end

      # Send a message from the assistant to the user
      def send(content, conversation:, metadata: {})
        message = Message.create!(
          conversation: conversation,
          role: 'assistant',
          content: content,
          metadata: metadata
        )

        broadcast_message(message)
        message
      end

      private

      def handle_web_message(message)
        Ai.logger.info "Routing web message to agent: #{message.content[0..50]}..."
        Jobs::AgentExecutorJob.perform_later(message.id)
      end

      def handle_cli_message(message)
        Ai.logger.info "Processing CLI message: #{message.content[0..50]}..."
        Jobs::AgentExecutorJob.perform_later(message.id)
      end

      def handle_whatsapp_message(message)
        Ai.logger.info "Processing WhatsApp message: #{message.content[0..50]}..."
        Jobs::AgentExecutorJob.perform_later(message.id)
      end

      def broadcast_message(message)
        # TODO: WebSocket broadcast for real-time UI updates
        Ai.logger.debug "Broadcasting message #{message.id}"
      end
    end
  end
end
