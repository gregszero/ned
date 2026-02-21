# frozen_string_literal: true

module Fang
  module Tools
    class BuildCanvasTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'build_canvas'
      description 'Create a page with multiple widgets in a single call. Auto-positions components in grid, stack, or freeform layout.'
      tool_group :canvas

      arguments do
        required(:title).filled(:string).description('Page title')
        required(:components).filled(:array).description('Array of component hashes: {type, metadata, content, width, x, y}')
        optional(:layout).filled(:string).description('Layout: "grid" (2-column, default), "stack" (single column), "freeform" (explicit x/y)')
        optional(:conversation_id).filled(:integer).description('Conversation to link (defaults to current)')
      end

      GRID_COLS = 2
      GRID_X_START = 60
      GRID_Y_START = 60
      GRID_X_GAP = 420
      GRID_Y_GAP = 400
      GRID_WIDTH = 380

      STACK_X = 60
      STACK_Y_START = 60
      STACK_Y_GAP = 400
      STACK_WIDTH = 600

      def call(title:, components:, layout: 'grid', conversation_id: nil)
        conversation = find_conversation(conversation_id)

        # Create or reuse page
        page = if conversation&.page
                 conversation.page
               else
                 p = Page.create!(title: title, content: '', status: 'published', published_at: Time.current)
                 conversation&.update!(page: p)
                 p
               end

        created = components.each_with_index.map do |comp, i|
          comp = comp.transform_keys(&:to_s)
          pos = position_for(layout, i, comp, components.size)

          comp_type = comp['type'] || 'card'
          metadata = comp['metadata'] || {}

          widget_class = Fang::Widgets::BaseWidget.for_type(comp_type)
          metadata = widget_class.default_metadata.merge(metadata) if widget_class

          component = page.canvas_components.create!(
            component_type: comp_type,
            content: comp['content'] || '',
            x: pos[:x], y: pos[:y],
            width: pos[:width],
            height: comp['height']&.to_f,
            z_index: 0,
            metadata: metadata
          )

          # Auto-render content from widget
          if component.content.blank?
            rendered = component.render_content_html
            component.update_column(:content, rendered) if rendered.present?
          end

          # Fetch live data for refreshable widgets
          if widget_class&.refreshable?
            widget = widget_class.new(component)
            widget.refresh_data! && component.reload
          end

          broadcast_component_add(page, component)

          { component_id: component.id, type: comp_type, x: pos[:x], y: pos[:y] }
        end

        {
          success: true,
          page_id: page.id,
          slug: page.slug,
          url: "/#{page.slug}",
          components_created: created.size,
          components: created
        }
      rescue => e
        Fang.logger.error "build_canvas failed: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def find_conversation(conversation_id)
        if conversation_id
          Conversation.find_by(id: conversation_id)
        elsif ENV['CONVERSATION_ID']
          Conversation.find_by(id: ENV['CONVERSATION_ID'])
        end
      end

      def position_for(layout, index, comp, _total)
        case layout
        when 'grid'
          col = index % GRID_COLS
          row = index / GRID_COLS
          { x: GRID_X_START + (col * GRID_X_GAP), y: GRID_Y_START + (row * GRID_Y_GAP), width: comp['width']&.to_f || GRID_WIDTH }
        when 'stack'
          { x: STACK_X, y: STACK_Y_START + (index * STACK_Y_GAP), width: comp['width']&.to_f || STACK_WIDTH }
        when 'freeform'
          { x: comp['x']&.to_f || 0, y: comp['y']&.to_f || 0, width: comp['width']&.to_f || 320 }
        else
          position_for('grid', index, comp, _total)
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
