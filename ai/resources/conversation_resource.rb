# frozen_string_literal: true

module Ai
  module Resources
    class ConversationResource
      include FastMcp::Resource

      resource_uri 'conversation://current'
      resource_name 'Current Conversation'
      description 'Context and history of the current conversation'

      def read
        # Get the most recent conversation (or from context if available)
        conversation = Conversation.order(last_message_at: :desc).first

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
