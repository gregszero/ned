# frozen_string_literal: true

require_relative '../../web/turbo_broadcast'
require_relative '../../web/view_helpers'

module Ai
  module Jobs
    class AgentExecutorJob < ApplicationJob
      include Web::ViewHelpers

      queue_as :agent_execution

      def perform(message_id)
        message = Message.find(message_id)
        conversation = message.conversation

        Ai.logger.info "Processing message #{message_id} for conversation #{conversation.id}"

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
        deliver_to_whatsapp(conversation, response_message) if response_message

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
        html = turbo_stream('append', "messages-#{conversation.id}") do
          <<~HTML
            <div class="chat-msg ai" id="thinking-indicator-#{conversation.id}">
              <div class="msg-meta flex items-center gap-2 mb-1">
                <span>AI</span>
              </div>
              <div class="prose-bubble">
                <p class="text-ned-muted-fg">Thinking...</p>
              </div>
            </div>
          HTML
        end

        Web::TurboBroadcast.broadcast(conversation.broadcast_channel, html)
      end

      def deliver_to_whatsapp(conversation, message)
        return unless conversation.source == 'whatsapp'

        phone = conversation.context&.dig('whatsapp_phone')
        return unless phone

        Ai::WhatsApp.send_message(phone: phone, content: message.content)
      rescue => e
        Ai.logger.error "WhatsApp delivery failed: #{e.message}"
      end

      def broadcast_response(conversation, message)
        html = turbo_stream('remove', "thinking-indicator-#{conversation.id}") {} +
               turbo_stream('append', "messages-#{conversation.id}") { render_message_html(message) }

        Web::TurboBroadcast.broadcast(conversation.broadcast_channel, html)
      end
    end
  end
end
