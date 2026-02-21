# frozen_string_literal: true

module Fang
  module Tools
    class GmailLabelsTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'gmail_labels'
      description 'List all Gmail labels and their IDs'
      tool_group :gmail

      arguments do
      end

      def call
        labels = Fang::Gmail.labels
        { success: true, labels: labels }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
