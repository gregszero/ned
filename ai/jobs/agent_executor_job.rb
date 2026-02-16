# frozen_string_literal: true

module Ai
  module Jobs
    class AgentExecutorJob < ApplicationJob
      queue_as :agent_execution

      # Execute a prompt via claude subprocess and save the response
      def perform(message_id)
        message = Message.find(message_id)
        conversation = message.conversation

        Ai.logger.info "Processing message #{message_id} for conversation #{conversation.id}"

        result = Agent.execute(
          prompt: message.content,
          session_id: conversation.id,
          conversation: conversation
        )

        case result['type']
        when 'content'
          conversation.add_message(
            role: 'assistant',
            content: result['content']
          )
          Ai.logger.info "Agent responded to message #{message_id}"
        when 'error'
          Ai.logger.error "Agent error: #{result['message']}"
          conversation.add_message(
            role: 'system',
            content: "Agent error: #{result['message']}"
          )
        end

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Message not found: #{e.message}"
      rescue => e
        Ai.logger.error "Agent execution failed: #{e.message}"
        Ai.logger.error e.backtrace.first(10).join("\n")
        conversation&.add_message(role: 'system', content: "Unexpected error: #{e.message}")
      end
    end
  end
end
