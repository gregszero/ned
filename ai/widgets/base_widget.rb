# frozen_string_literal: true

module Ai
  module Widgets
    class BaseWidget
      class << self
        attr_reader :widget_type_name, :menu_label_text, :menu_icon_text

        def widget_type(name)  = @widget_type_name = name.to_s
        def menu_label(label)  = @menu_label_text = label
        def menu_icon(icon)    = @menu_icon_text = icon
        def refreshable?       = false
        def refresh_interval   = nil
        def default_metadata   = {}

        def registry
          @registry ||= ObjectSpace.each_object(Class)
            .select { |c| c < BaseWidget && c.widget_type_name }
            .each_with_object({}) { |c, h| h[c.widget_type_name] = c }
        end

        def reset_registry! = @registry = nil
        def for_type(type)  = registry[type.to_s]
      end

      def initialize(component)
        @component = component
        @metadata = component.metadata || {}
      end

      def render_content
        @component.content || ''
      end

      def render_component_html
        c = @component
        style = "left:#{c.x}px;top:#{c.y}px;width:#{c.width}px;"
        style += "height:#{c.height}px;" if c.height
        meta_json = (@metadata || {}).to_json.gsub('"', '&quot;')
        <<~HTML
          <div class="canvas-component" id="canvas-component-#{c.id}"
               data-component-id="#{c.id}" data-widget-type="#{c.component_type}"
               data-widget-metadata="#{meta_json}"
               style="#{style}" data-z="#{c.z_index}">
            <div class="canvas-component-content">#{render_content}</div>
          </div>
        HTML
      end

      def refresh_data!
        false
      end
    end
  end
end
