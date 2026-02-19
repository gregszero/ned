# frozen_string_literal: true

module Fang
  module Tools
    class CreatePageTool < FastMcp::Tool
      tool_name 'create_page'
      description 'Create a web page that appears in the sidebar navigation'

      arguments do
        required(:title).filled(:string).description('Page title (also generates the URL slug)')
        required(:content).filled(:string).description('HTML content for the page body')
        optional(:status).filled(:string).description('Page status: published (default), draft, or archived')
      end

      def call(title:, content:, status: 'published')
        page = Page.create!(
          title: title,
          content: content,
          status: status,
          published_at: status == 'published' ? Time.current : nil
        )

        # Link to current conversation if available
        if ENV['CONVERSATION_ID']
          conversation = Fang::Conversation.find_by(id: ENV['CONVERSATION_ID'])
          conversation&.update!(page: page) if conversation && conversation.page_id.nil?
        end

        Fang.logger.info "Created page '#{page.title}' at /pages/#{page.slug}"

        {
          success: true,
          page_id: page.id,
          title: page.title,
          slug: page.slug,
          url: "/pages/#{page.slug}",
          status: page.status
        }
      rescue => e
        Fang.logger.error "Failed to create page: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
