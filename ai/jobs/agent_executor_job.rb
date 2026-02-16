# frozen_string_literal: true

require_relative '../../web/turbo_broadcast'

module Ai
  module Jobs
    class AgentExecutorJob < ApplicationJob
      queue_as :agent_execution

      # Execute a prompt via claude subprocess and save the response
      def perform(message_id)
        message = Message.find(message_id)
        conversation = message.conversation

        Ai.logger.info "Processing message #{message_id} for conversation #{conversation.id}"

        # Show thinking indicator via Turbo Stream
        broadcast_thinking(conversation)

        result = Agent.execute(
          prompt: message.content,
          session_id: conversation.id,
          conversation: conversation
        )

        response_message = case result['type']
        when 'content'
          msg = conversation.add_message(role: 'assistant', content: result['content'])
          Ai.logger.info "Agent responded to message #{message_id}"
          msg
        when 'error'
          Ai.logger.error "Agent error: #{result['message']}"
          conversation.add_message(role: 'system', content: "Agent error: #{result['message']}")
        end

        broadcast_response(conversation, response_message) if response_message

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Message not found: #{e.message}"
      rescue => e
        Ai.logger.error "Agent execution failed: #{e.message}"
        Ai.logger.error e.backtrace.first(10).join("\n")
        error_msg = conversation&.add_message(role: 'system', content: "Unexpected error: #{e.message}")
        broadcast_response(conversation, error_msg) if conversation && error_msg
      end

      private

      def broadcast_thinking(conversation)
        html = <<~HTML
          <turbo-stream action="append" target="messages">
            <template>
              <div class="chat chat-start" id="thinking-indicator">
                <div class="chat-header text-xs text-base-content/50 mb-1">AI</div>
                <div class="chat-bubble chat-bubble-secondary">
                  <span class="loading loading-dots loading-sm"></span>
                </div>
              </div>
            </template>
          </turbo-stream>
        HTML

        Web::TurboBroadcast.broadcast("conversation:#{conversation.id}", html)
      end

      def broadcast_response(conversation, message)
        role_class = message.role == 'user' ? 'chat-end' : 'chat-start'
        bubble_class = message.role == 'user' ? 'chat-bubble-primary' : 'chat-bubble-secondary'
        label = message.role == 'user' ? 'You' : 'AI'
        time = message.created_at.strftime('%I:%M %p')
        content = message.content.gsub("\n", '<br>').gsub('"', '&quot;')

        html = <<~HTML
          <turbo-stream action="remove" target="thinking-indicator">
            <template></template>
          </turbo-stream>
          <turbo-stream action="append" target="messages">
            <template>
              <div class="chat #{role_class}" id="message-#{message.id}">
                <div class="chat-header text-xs text-base-content/50 mb-1">
                  #{label}
                  <time class="ml-1">#{time}</time>
                </div>
                <div class="chat-bubble #{bubble_class}">
                  #{content}
                </div>
              </div>
            </template>
          </turbo-stream>
        HTML

        Web::TurboBroadcast.broadcast("conversation:#{conversation.id}", html)
      end
    end
  end
end
