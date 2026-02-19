# frozen_string_literal: true

module Fang
  module Tools
    class GmailSendTool < FastMcp::Tool
      tool_name 'gmail_send'
      description 'Send an email'

      arguments do
        required(:to).filled(:string).description('Recipient email address')
        required(:subject).filled(:string).description('Email subject')
        required(:body).filled(:string).description('Email body')
        optional(:html).filled(:bool).description('Send as HTML (default false)')
      end

      def call(to:, subject:, body:, html: false)
        result = Fang::Gmail.send_email(to: to, subject: subject, body: body, html: html)
        { success: true, **result }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
