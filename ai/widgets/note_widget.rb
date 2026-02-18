# frozen_string_literal: true

module Ai
  module Widgets
    class NoteWidget < BaseWidget
      widget_type 'card'
      menu_label 'Add Note'
      menu_icon "\u{1F4DD}"

      def render_content
        @metadata['text'] || @component.content || '<p style="color:var(--muted-foreground);margin:0">Double-click to edit...</p>'
      end
    end
  end
end
