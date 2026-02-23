# frozen_string_literal: true

module Fang
  module Widgets
    class ChartWidget < BaseWidget
      widget_type 'chart'
      menu_label 'Add Chart'
      menu_icon "\u{1F4CA}"
      menu_category 'Data'

      def self.header_title = 'Chart'
      def self.header_color = '#f97316'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>'
      end

      def self.default_metadata
        { 'chart_type' => 'bar', 'title' => 'Chart', 'labels' => [], 'datasets' => [], 'options' => {} }
      end

      def render_content
        chart_type = @metadata['chart_type'] || 'bar'
        title = @metadata['title'] || 'Chart'
        labels = @metadata['labels'] || []
        datasets = @metadata['datasets'] || []
        options = @metadata['options'] || {}

        config = { type: chart_type, labels: labels, datasets: datasets, options: options }.to_json

        <<~HTML
          <div class="flex flex-col gap-2 p-3" style="height:100%;min-height:200px">
            <div class="text-sm font-semibold" style="color:var(--foreground)">#{h title}</div>
            <div style="flex:1;position:relative;min-height:160px" data-ned-chart='#{config.gsub("'", "&#39;")}'>
              <canvas></canvas>
            </div>
          </div>
        HTML
      end
    end
  end
end
