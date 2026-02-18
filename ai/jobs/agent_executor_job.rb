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
        channel = conversation.broadcast_channel

        Ai.logger.info "Processing message #{message_id} for conversation #{conversation.id}"

        progress_id = "agent-progress-#{message_id}"
        broadcast_progress_container(conversation, progress_id)
        broadcast_step(channel, progress_id, 'Thinking...', 'thinking')

        accumulated_text = ""

        Agent.execute_streaming(
          prompt: message.content,
          session_id: conversation.id,
          conversation: conversation
        ) do |event|
          case event['type']
          when 'assistant'
            (event['content'] || []).each do |block|
              case block['type']
              when 'thinking'
                broadcast_step(channel, progress_id, 'Thinking...', 'thinking')
              when 'tool_use'
                broadcast_step(channel, progress_id, "Running #{block['name']}", 'tool')
              when 'text'
                accumulated_text = block['text'].to_s
                broadcast_streaming_text(channel, progress_id, accumulated_text)
              end
            end

          when 'result'
            result_text = event['result'].to_s.strip
            result_text = accumulated_text.strip if result_text.empty?
            result_text = summarize_result(event) if result_text.empty?

            role = event['subtype'] == 'success' ? 'assistant' : 'system'
            response_message = conversation.add_message(role: role, content: result_text)
            Ai.logger.info "Agent responded to message #{message_id}"
            broadcast_final(conversation, progress_id, response_message)
            deliver_to_whatsapp(conversation, response_message)

          when 'error'
            Ai.logger.error "Agent error: #{event['message']}"
            error_msg = conversation.add_message(role: 'system', content: "Agent error: #{event['message']}")
            broadcast_final(conversation, progress_id, error_msg)
          end
        end

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Message not found: #{e.message}"
      rescue => e
        Ai.logger.error "Agent execution failed: #{e.message}"
        Ai.logger.error e.backtrace.first(10).join("\n")
        error_msg = conversation&.add_message(role: 'system', content: "Unexpected error: #{e.message}")
        broadcast_final(conversation, "agent-progress-#{message_id}", error_msg) if conversation && error_msg
      end

      private

      def broadcast_progress_container(conversation, progress_id)
        html = turbo_stream('append', "messages-#{conversation.id}") do
          <<~HTML
            <div class="chat-msg ai" id="#{progress_id}">
              <div class="msg-meta flex items-center gap-2 mb-1">
                <span>AI</span>
              </div>
              <div class="agent-steps" id="#{progress_id}-steps"></div>
              <div class="prose-bubble" id="#{progress_id}-response"></div>
            </div>
          HTML
        end
        Web::TurboBroadcast.broadcast(conversation.broadcast_channel, html)
      end

      def broadcast_step(channel, progress_id, label, kind)
        html = turbo_stream('append', "#{progress_id}-steps") do
          <<~HTML
            <div class="agent-step" data-kind="#{kind}">
              <span class="agent-step-icon"></span>
              <span>#{ERB::Util.html_escape(label)}</span>
            </div>
          HTML
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def broadcast_streaming_text(channel, progress_id, text)
        html = turbo_stream('update', "#{progress_id}-response") do
          <<~HTML
            <div class="prose">#{render_markdown(text)}</div>
          HTML
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def summarize_result(event)
        parts = []
        parts << "Completed in #{event['num_turns']} turn(s)." if event['num_turns']
        parts << "Cost: $#{'%.4f' % event['total_cost_usd']}." if event['total_cost_usd']
        parts.empty? ? "Task completed." : parts.join(' ')
      end

      def broadcast_final(conversation, progress_id, message)
        html = turbo_stream('remove', progress_id) {} +
               turbo_stream('append', "messages-#{conversation.id}") { render_message_html(message) }
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
    end
  end
end
