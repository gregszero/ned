# frozen_string_literal: true

module Ai
  module Resources
    class ConversationResource < FastMcp::Resource
      uri 'conversation://current'
      resource_name 'Current Conversation'
      description 'Context and history of the current conversation'

      def content
        # Use CONVERSATION_ID env var (set by agent.rb) or fall back to most recent
        conversation = if ENV['CONVERSATION_ID']
          Conversation.find_by(id: ENV['CONVERSATION_ID'])
        end
        conversation ||= Conversation.order(last_message_at: :desc).first

        return { error: 'No conversations found' }.to_json unless conversation

        {
          id: conversation.id,
          title: conversation.title,
          source: conversation.source,
          created_at: conversation.created_at,
          last_message_at: conversation.last_message_at,
          message_count: conversation.messages.count,
          recent_messages: conversation.latest_messages(10).map do |msg|
            {
              id: msg.id,
              role: msg.role,
              content: msg.truncated_content(200),
              created_at: msg.created_at
            }
          end,
          active_session: conversation.active_session&.then do |session|
            {
              id: session.id,
              session_uuid: session.session_uuid,
              status: session.status,
              started_at: session.started_at,
              duration: session.duration
            }
          end,
          context: conversation.context
        }.to_json
      end
    end
  end
end
