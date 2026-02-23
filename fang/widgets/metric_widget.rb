# frozen_string_literal: true

module Fang
  module Widgets
    class MetricWidget < BaseWidget
      widget_type 'metric'
      menu_label 'Add Metric'
      menu_icon "\u{1F4C8}"
      menu_category 'Data'

      def self.header_title = 'Metric'
      def self.header_color = '#22d3ee'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>'
      end

      def self.refreshable?     = true
      def self.refresh_interval  = 300

      def self.default_metadata
        { 'value' => '—', 'label' => 'Metric', 'trend' => nil, 'trend_direction' => nil }
      end

      def render_content
        value = @metadata['value'] || '—'
        label = @metadata['label'] || 'Metric'
        trend = @metadata['trend']
        direction = @metadata['trend_direction']

        trend_html = if trend
          color = case direction
                  when 'up' then 'color:#22c55e'
                  when 'down' then 'color:#ef4444'
                  else 'color:var(--muted-foreground)'
                  end
          arrow = case direction
                  when 'up' then '&#9650; '
                  when 'down' then '&#9660; '
                  else ''
                  end
          %(<div class="text-xs font-medium mt-1" style="#{color}">#{arrow}#{h trend}</div>)
        else
          ''
        end

        <<~HTML
          <div class="flex flex-col items-center justify-center gap-1 p-4 text-center" style="min-height:100px">
            <div class="text-xs font-medium tracking-wide" style="color:var(--muted-foreground)">#{h label}</div>
            <div class="text-3xl font-bold" style="color:var(--foreground)">#{h value}</div>
            #{trend_html}
          </div>
        HTML
      end

      def refresh_data!
        result = evaluate_data_source
        return false unless result

        @metadata['value'] = result.to_s
        @component.update!(content: render_content, metadata: @metadata)
        true
      end
    end
  end
end
