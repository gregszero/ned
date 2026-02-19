# frozen_string_literal: true

module Fang
  module Tools
    class GmailSearchTool < FastMcp::Tool
      tool_name 'gmail_search'
      description 'Search emails using Gmail query syntax (e.g. "is:unread", "from:alice", "newer_than:1d subject:meeting")'

      arguments do
        required(:query).filled(:string).description('Gmail search query')
        optional(:max_results).filled(:integer).description('Max results to return (default 10)')
      end

      def call(query:, max_results: 10)
        results = Fang::Gmail.search(query, max_results: max_results)
        { success: true, count: results.size, messages: results }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
