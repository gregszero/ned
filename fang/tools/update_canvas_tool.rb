# frozen_string_literal: true

module Fang
  module Tools
    class UpdateCanvasTool < FastMcp::Tool
      tool_name 'update_canvas'
      description 'Update the canvas area for the current conversation with HTML content. The canvas is a large display area above the chat that can show rich content like dashboards, reports, or interactive pages. Creates a named Page if none exists.'

      arguments do
        required(:html).filled(:string).description('HTML content to display in the canvas')
        optional(:title).filled(:string).description('Canvas page title (used when creating a new canvas page)')
        optional(:conversation_id).filled(:integer).description('Conversation ID (defaults to current)')
        optional(:mode).filled(:string).description('How to update: "replace" (default) replaces all content, "append" adds to existing content')
      end

      def call(html:, title: nil, conversation_id: nil, mode: 'replace')
        conversation = if conversation_id
          Fang::Conversation.find(conversation_id)
        elsif ENV['CONVERSATION_ID']
          Fang::Conversation.find(ENV['CONVERSATION_ID'])
        else
          Fang::Conversation.last
        end

        unless conversation
          return { success: false, error: 'No conversation found' }
        end

        # Auto-create an Page if conversation has none
        page = conversation.page
        unless page
          page_title = title || conversation.title || 'Canvas'
          page = Fang::Page.create!(
            title: page_title,
            content: '',
            status: 'published',
            published_at: Time.current
          )
          conversation.update!(page: page)
        end

        # Update page content
        if mode == 'append'
          page.update!(content: (page.content || '') + html)
        else
          page.update!(content: html)
        end

        # Broadcast to ALL conversations sharing this page
        action = mode == 'append' ? 'append' : 'update'
        target = "canvas-page-#{page.id}"
        stream_html = "<turbo-stream action=\"#{action}\" target=\"#{target}\"><template>#{html}</template></turbo-stream>"

        Fang::Web::TurboBroadcast.broadcast("canvas:#{page.id}", stream_html)

        { success: true, mode: mode, conversation_id: conversation.id, page_id: page.id, slug: page.slug }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
