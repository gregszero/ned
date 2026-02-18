# frozen_string_literal: true

module Ai
  module Tools
    class AddCanvasComponentTool < FastMcp::Tool
      tool_name 'add_canvas_component'
      description 'Add a component/widget to the current canvas page'

      arguments do
        required(:content).filled(:string).description('HTML content for the component')
        optional(:component_type).filled(:string).description('Component type (default: card)')
        optional(:x).filled(:float).description('X position (default: 0)')
        optional(:y).filled(:float).description('Y position (default: 0)')
        optional(:width).filled(:float).description('Width in pixels (default: 320)')
        optional(:height).filled(:float).description('Height in pixels (null = auto)')
        optional(:z_index).filled(:integer).description('Z-index for layering (default: 0)')
        optional(:metadata).filled(:hash).description('Arbitrary metadata hash')
      end

      def call(content:, component_type: 'card', x: 0, y: 0, width: 320, height: nil, z_index: 0, metadata: {})
        page = find_page
        return { success: false, error: 'No canvas page found for this conversation' } unless page

        component = page.canvas_components.create!(
          component_type: component_type,
          content: content,
          x: x, y: y,
          width: width, height: height,
          z_index: z_index,
          metadata: metadata || {}
        )

        broadcast_component_add(page, component)

        {
          success: true,
          component_id: component.id,
          page_id: page.id
        }
      rescue => e
        Ai.logger.error "Failed to add canvas component: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def find_page
        if ENV['AI_PAGE_ID']
          AiPage.find_by(id: ENV['AI_PAGE_ID'])
        elsif ENV['CONVERSATION_ID']
          Conversation.find_by(id: ENV['CONVERSATION_ID'])&.ai_page
        end
      end

      def broadcast_component_add(page, component)
        html = component_html(component)
        turbo = "<turbo-stream action=\"append\" target=\"canvas-components-#{page.id}\"><template>#{html}</template></turbo-stream>"
        broadcast_to_page(page, turbo)
      end

      def component_html(c)
        style = "left:#{c.x}px;top:#{c.y}px;width:#{c.width}px;"
        style += "height:#{c.height}px;" if c.height
        <<~HTML
          <div class="canvas-component" id="canvas-component-#{c.id}" data-component-id="#{c.id}" style="#{style}" data-z="#{c.z_index}">
            <div class="canvas-component-content">#{c.content}</div>
          </div>
        HTML
      end

      def broadcast_to_page(page, turbo)
        Ai::Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
      end
    end
  end
end
