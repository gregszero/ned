# frozen_string_literal: true

module Fang
  module Widgets
    class ListWidget < BaseWidget
      widget_type 'list'
      menu_label 'Add List'
      menu_icon "\u{1F4CB}"
      menu_category 'Content'

      def self.header_title = 'List'
      def self.header_color = '#a78bfa'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>'
      end

      def self.refreshable?     = true
      def self.refresh_interval  = 300

      def self.default_metadata
        { 'title' => 'List', 'items' => [] }
      end

      def render_content
        title = @metadata['title'] || 'List'
        items = @metadata['items'] || []

        return %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">Empty list</div>) if items.empty?

        items_html = items.map do |item|
          text = item.is_a?(Hash) ? item['text'] : item.to_s
          subtitle = item.is_a?(Hash) ? item['subtitle'] : nil
          url = item.is_a?(Hash) ? item['url'] : nil

          content = if url
            %(<a href="#{h url}" class="font-medium hover:underline" style="color:var(--primary)">#{h text}</a>)
          else
            %(<span class="font-medium" style="color:var(--foreground)">#{h text}</span>)
          end

          subtitle_html = subtitle ? %(<div class="text-xs" style="color:var(--muted-foreground)">#{h subtitle}</div>) : ''

          <<~HTML
            <div class="flex flex-col gap-0.5 py-2 px-3" style="border-bottom:1px solid var(--border)">
              #{content}
              #{subtitle_html}
            </div>
          HTML
        end.join

        <<~HTML
          <div class="flex flex-col">
            <div class="text-sm font-semibold p-3 pb-1" style="color:var(--foreground)">#{h title}</div>
            #{items_html}
          </div>
        HTML
      end

      def refresh_data!
        result = evaluate_data_source
        return false unless result.is_a?(Array)

        @metadata['items'] = result.map do |item|
          item.is_a?(Hash) ? item.transform_keys(&:to_s) : { 'text' => item.to_s }
        end
        @component.update!(content: render_content, metadata: @metadata)
        true
      end
    end
  end
end
