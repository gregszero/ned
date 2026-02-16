# frozen_string_literal: true

module Ai
  module Jobs
    class AgentExecutorJob < ApplicationJob
      queue_as :agent_execution

      # Main AI orchestration job
      # Spawns container, sends message, streams responses
      def perform(message_id)
        message = Message.find(message_id)
        conversation = message.conversation

        Ai.logger.info "Processing message #{message_id} for conversation #{conversation.id}"

        # Get or create session
        session = conversation.active_session || spawn_new_session(conversation)

        unless session.running?
          Ai.logger.error "Session #{session.id} is not running (status: #{session.status})"
          create_error_message(conversation, "Agent session failed to start")
          return
        end

        # Send message to container
        begin
          Container.send_message(session, message.content)
        rescue => e
          Ai.logger.error "Failed to send message: #{e.message}"
          session.error!
          create_error_message(conversation, "Failed to communicate with agent: #{e.message}")
          return
        end

        # Read and stream response
        stream_response(session, conversation)

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Message not found: #{e.message}"
      rescue => e
        Ai.logger.error "Agent execution failed: #{e.message}"
        Ai.logger.error e.backtrace.first(10).join("\n")
        create_error_message(conversation, "Unexpected error: #{e.message}")
      end

      private

      def spawn_new_session(conversation)
        Ai.logger.info "Spawning new container for conversation #{conversation.id}"

        session = Container.spawn(conversation.id)

        # Wait a moment for container to be ready
        sleep 2

        session
      rescue => e
        Ai.logger.error "Failed to spawn container: #{e.message}"
        # Create a failed session record
        Session.create!(
          conversation: conversation,
          status: 'error'
        )
      end

      def stream_response(session, conversation)
        response_content = []

        # Create a placeholder message for streaming
        response_message = conversation.add_message(
          role: 'assistant',
          content: '',
          streaming: true
        )

        Container.read_response(session) do |data|
          case data['type']
          when 'content'
            # Accumulate content
            response_content << data['content']

            # Update message with accumulated content
            response_message.update!(
              content: response_content.join,
              streaming: !data['done']
            )

            # TODO: Broadcast via Solid Cable for real-time updates

            Ai.logger.debug "Received content chunk: #{data['content'][0..50]}..."
          when 'error'
            Ai.logger.error "Agent error: #{data['message']}"
            response_message.update!(
              content: "Error: #{data['message']}",
              streaming: false
            )
            break
          end
        end

        # Mark as complete
        response_message.update!(streaming: false) if response_message.streaming?

        Ai.logger.info "Completed message #{response_message.id}"
      rescue => e
        Ai.logger.error "Failed to stream response: #{e.message}"
        response_message&.update!(
          content: "Error reading response: #{e.message}",
          streaming: false
        )
      end

      def create_error_message(conversation, error_text)
        conversation.add_message(
          role: 'system',
          content: error_text
        )
      end
    end
  end
end
