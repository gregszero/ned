# frozen_string_literal: true

module Ai
  module Tools
    class RemoveCanvasComponentTool < FastMcp::Tool
      tool_name 'remove_canvas_component'
      description 'Remove a component from the canvas'

      arguments do
        required(:component_id).filled(:integer).description('ID of the component to remove')
      end

      def call(component_id:)
        component = CanvasComponent.find_by(id: component_id)
        return { success: false, error: "Component #{component_id} not found" } unless component

        page = component.ai_page
        component.destroy!

        turbo = "<turbo-stream action=\"remove\" target=\"canvas-component-#{component_id}\"><template></template></turbo-stream>"
        Ai::Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)

        {
          success: true,
          removed_id: component_id
        }
      rescue => e
        Ai.logger.error "Failed to remove canvas component: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
