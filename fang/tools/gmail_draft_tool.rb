# frozen_string_literal: true

module Fang
  module Tools
    class GmailDraftTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'gmail_draft'
      description 'Create an email draft without sending it'
      tool_group :gmail

      arguments do
        required(:to).filled(:string).description('Recipient email address')
        required(:subject).filled(:string).description('Email subject')
        required(:body).filled(:string).description('Email body')
      end

      def call(to:, subject:, body:)
        result = Fang::Gmail.draft(to: to, subject: subject, body: body)
        { success: true, **result }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
