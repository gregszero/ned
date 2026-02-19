# frozen_string_literal: true

module Ai
  module Tools
    class GetCanvasTool < FastMcp::Tool
      tool_name 'get_canvas'
      description 'Get all components on the current canvas page'

      arguments do
        optional(:page_id).filled(:integer).description('Page ID (defaults to current conversation page)')
      end

      def call(page_id: nil)
        page = if page_id
          AiPage.find_by(id: page_id)
        elsif ENV['AI_PAGE_ID']
          AiPage.find_by(id: ENV['AI_PAGE_ID'])
        elsif ENV['CONVERSATION_ID']
          Conversation.find_by(id: ENV['CONVERSATION_ID'])&.ai_page
        end

        return { success: false, error: 'No canvas page found' } unless page

        {
          success: true,
          page_id: page.id,
          title: page.title,
          components: page.canvas_components.ordered.map(&:as_canvas_json),
          canvas_state: page.canvas_state || {}
        }
      rescue => e
        Ai.logger.error "Failed to get canvas: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
