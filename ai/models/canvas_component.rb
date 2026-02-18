# frozen_string_literal: true

module Ai
  class CanvasComponent < ActiveRecord::Base
    self.table_name = 'canvas_components'

    belongs_to :ai_page

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
  end
end
