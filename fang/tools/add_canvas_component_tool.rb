# frozen_string_literal: true

module Fang
  module Tools
    class AddCanvasComponentTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'add_canvas_component'
      description 'Add a component/widget to the current canvas page'
      tool_group :canvas

      arguments do
        optional(:content).filled(:string).description('HTML content (auto-rendered from widget type if blank)')
        optional(:component_type).filled(:string).description('Widget type: card, clock, weather, hacker_news (default: card)')
        optional(:x).filled(:float).description('X position (default: 0)')
        optional(:y).filled(:float).description('Y position (default: 0)')
        optional(:width).filled(:float).description('Width in pixels (default: 320)')
        optional(:height).filled(:float).description('Height in pixels (null = auto)')
        optional(:z_index).filled(:integer).description('Z-index for layering (default: 0)')
        optional(:metadata).filled(:hash).description('Widget metadata hash (e.g. {city: "Zurich"} for weather)')
      end

      def call(content: nil, component_type: 'card', x: 0, y: 0, width: 320, height: nil, z_index: 0, metadata: {})
        page = find_page
        return { success: false, error: 'No canvas page found for this conversation' } unless page

        # Merge widget default metadata
        widget_class = Fang::Widgets::BaseWidget.for_type(component_type)
        if widget_class
          metadata = widget_class.default_metadata.merge(metadata || {})
        end

        component = page.canvas_components.create!(
          component_type: component_type,
          content: content || '',
          x: x, y: y,
          width: width, height: height,
          z_index: z_index,
          metadata: metadata || {}
        )

        # Auto-render content from widget if content is blank
        if component.content.blank?
          rendered = component.render_content_html
          component.update_column(:content, rendered) if rendered.present?
        end

        # Fetch live data immediately for refreshable widgets (e.g. weather)
        if widget_class&.refreshable?
          widget = widget_class.new(component)
          if widget.refresh_data!
            component.reload
          end
        end

        broadcast_component_add(page, component)

        {
          success: true,
          component_id: component.id,
          page_id: page.id
        }
      rescue => e
        Fang.logger.error "Failed to add canvas component: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def find_page
        if ENV['PAGE_ID']
          Page.find_by(id: ENV['PAGE_ID'])
        elsif ENV['CONVERSATION_ID']
          Conversation.find_by(id: ENV['CONVERSATION_ID'])&.page
        end
      end

      def broadcast_component_add(page, component)
        html = component.render_html
        turbo = "<turbo-stream action=\"append\" target=\"canvas-components-#{page.id}\"><template>#{html}</template></turbo-stream>"
        Fang::Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
      end
    end
  end
end
