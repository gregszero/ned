# frozen_string_literal: true

module Fang
  class CanvasComponent < ActiveRecord::Base
    self.table_name = 'canvas_components'

    belongs_to :page

    scope :ordered, -> { order(:z_index, :created_at) }

    validates :component_type, presence: true
    validates :x, :y, :width, presence: true

    def as_canvas_json
      {
        id: id,
        type: component_type,
        content: content,
        x: x,
        y: y,
        width: width,
        height: height,
        z_index: z_index,
        metadata: metadata || {}
      }
    end

    def render_html
      widget_class = Fang::Widgets::BaseWidget.for_type(component_type)
      widget_class ? widget_class.new(self).render_component_html : fallback_html
    end

    def render_content_html
      widget_class = Fang::Widgets::BaseWidget.for_type(component_type)
      widget_class ? widget_class.new(self).render_content : content
    end

    private

    def fallback_html
      style = "left:#{x}px;top:#{y}px;width:#{width}px;"
      style += "height:#{height}px;" if height
      <<~HTML
        <div class="canvas-component" id="canvas-component-#{id}" data-component-id="#{id}" style="#{style}" data-z="#{z_index}">
          <div class="canvas-component-content">#{content}</div>
        </div>
      HTML
    end
  end
end
