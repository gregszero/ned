# frozen_string_literal: true

module Fang
  module Tools
    class UpdateCanvasComponentTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'update_canvas_component'
      description 'Update an existing canvas component (content, position, or size)'
      tool_group :canvas

      arguments do
        required(:component_id).filled(:integer).description('ID of the component to update')
        optional(:content).filled(:string).description('New HTML content')
        optional(:x).filled(:float).description('New X position')
        optional(:y).filled(:float).description('New Y position')
        optional(:width).filled(:float).description('New width')
        optional(:height).filled(:float).description('New height')
        optional(:z_index).filled(:integer).description('New z-index')
        optional(:metadata).filled(:hash).description('Metadata to merge')
      end

      def call(component_id:, content: nil, x: nil, y: nil, width: nil, height: nil, z_index: nil, metadata: nil)
        component = CanvasComponent.find_by(id: component_id)
        return { success: false, error: "Component #{component_id} not found" } unless component

        updates = {}
        updates[:content] = content if content
        updates[:x] = x if x
        updates[:y] = y if y
        updates[:width] = width if width
        updates[:height] = height if height
        updates[:z_index] = z_index if z_index
        updates[:metadata] = (component.metadata || {}).merge(metadata) if metadata

        component.update!(updates) if updates.any?

        broadcast_component_replace(component)

        {
          success: true,
          component: component.as_canvas_json
        }
      rescue => e
        Fang.logger.error "Failed to update canvas component: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def broadcast_component_replace(component)
        html = component.render_html
        turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\"><template>#{html}</template></turbo-stream>"
        Fang::Web::TurboBroadcast.broadcast("canvas:#{component.page.id}", turbo)
      end
    end
  end
end
