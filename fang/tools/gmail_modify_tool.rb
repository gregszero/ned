# frozen_string_literal: true

module Fang
  module Tools
    class GmailModifyTool < FastMcp::Tool
      tool_name 'gmail_modify'
      description 'Add or remove labels on an email (mark read, archive, star, etc). Common labels: UNREAD, STARRED, INBOX, SPAM, TRASH'

      arguments do
        required(:message_id).filled(:string).description('Gmail message ID')
        optional(:add_labels).filled(:array).description('Label IDs to add (e.g. ["STARRED", "UNREAD"])')
        optional(:remove_labels).filled(:array).description('Label IDs to remove (e.g. ["UNREAD", "INBOX"])')
      end

      def call(message_id:, add_labels: [], remove_labels: [])
        Fang::Gmail.modify(message_id, add_labels: add_labels, remove_labels: remove_labels)
        { success: true, message_id: message_id }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
