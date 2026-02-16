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

        # Broadcast to appropriate channel based on conversation source
        broadcast_message(message)

        message
      end

      private

      def handle_web_message(message)
        # Enqueue job to process with AI
        # Will be implemented when jobs are set up
        Ai.logger.info "Routing web message to agent: #{message.content[0..50]}..."
      end

      def handle_cli_message(message)
        # Process synchronously for CLI
        Ai.logger.info "Processing CLI message: #{message.content[0..50]}..."
      end

      def broadcast_message(message)
        # Will be implemented with Solid Cable
        Ai.logger.debug "Broadcasting message #{message.id}"
      end
    end
  end
end
