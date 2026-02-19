# frozen_string_literal: true

module Fang
  module Widgets
    class BaseWidget
      DRAG_HANDLE = '<div class="canvas-drag-handle"><svg width="12" height="14" viewBox="0 0 12 14" fill="currentColor"><circle cx="3" cy="2" r="1.5"/><circle cx="9" cy="2" r="1.5"/><circle cx="3" cy="7" r="1.5"/><circle cx="9" cy="7" r="1.5"/><circle cx="3" cy="12" r="1.5"/><circle cx="9" cy="12" r="1.5"/></svg></div>'

      class << self
        attr_reader :widget_type_name, :menu_label_text, :menu_icon_text

        def widget_type(name)  = @widget_type_name = name.to_s
        def menu_label(label)  = @menu_label_text = label
        def menu_icon(icon)    = @menu_icon_text = icon
        def refreshable?       = false
        def refresh_interval   = nil
        def default_metadata   = {}

        # Header defaults — override in subclasses
        def header_title = nil
        def header_color = '#a1a1aa'
        def header_icon  = nil

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

      def render_header
        title = @metadata['title'] || self.class.header_title
        return '' unless title
        color = @metadata['title_color'] || self.class.header_color
        icon = self.class.header_icon
        icon_html = icon ? %(<span class="header-icon">#{icon}</span>) : ''
        <<~HTML
          <div class="canvas-component-header" style="color:#{color}">
            #{icon_html}<span>#{h(title)}</span>
          </div>
        HTML
      end

      def render_component_html
        c = @component
        style = "left:#{c.x}px;top:#{c.y}px;width:#{c.width}px;"
        style += "height:#{c.height}px;" if c.height
        font_size = @metadata['font_size']
        font_class = case font_size
                     when 'sm' then ' font-sm'
                     when 'lg' then ' font-lg'
                     else ''
                     end
        meta_json = (@metadata || {}).to_json.gsub('"', '&quot;')
        <<~HTML
          <div class="canvas-component#{font_class}" id="canvas-component-#{c.id}"
               data-component-id="#{c.id}" data-widget-type="#{c.component_type}"
               data-widget-metadata="#{meta_json}"
               style="#{style}" data-z="#{c.z_index}">
            #{DRAG_HANDLE}#{render_header}<div class="canvas-component-content">#{render_content}</div>
          </div>
        HTML
      end

      def refresh_data!
        false
      end

      private

      def evaluate_data_source
        source = @metadata['data_source']
        return nil unless source.is_a?(String) && !source.empty?

        ctx = Object.new
        Fang.constants.map { |c| Fang.const_get(c) }
          .select { |c| c.is_a?(Class) && c < ActiveRecord::Base }
          .each { |model| ctx.define_singleton_method(model.name.demodulize.to_sym) { model } }
        ctx.instance_eval(source)
      rescue => e
        Fang.logger.error "Data source evaluation failed: #{e.message}"
        nil
      end

      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end
    end
  end
end
