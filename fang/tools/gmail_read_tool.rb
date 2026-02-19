# frozen_string_literal: true

module Fang
  module Tools
    class GmailReadTool < FastMcp::Tool
      tool_name 'gmail_read'
      description 'Read the full content of an email by message ID'

      arguments do
        required(:message_id).filled(:string).description('Gmail message ID')
      end

      def call(message_id:)
        message = Fang::Gmail.read(message_id)
        { success: true, message: message }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
