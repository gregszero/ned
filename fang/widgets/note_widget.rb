# frozen_string_literal: true

module Fang
  module Widgets
    class NoteWidget < BaseWidget
      widget_type 'card'
      menu_label 'Add Note'
      menu_icon "\u{1F4DD}"
      menu_category 'Content'

      def self.header_title = 'Note'
      def self.header_color = '#a1a1aa'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>'
      end

      def render_content
        @metadata['text'] || @component.content || '<p style="color:var(--muted-foreground);margin:0">Double-click to edit...</p>'
      end
    end
  end
end
