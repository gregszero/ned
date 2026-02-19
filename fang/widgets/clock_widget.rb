# frozen_string_literal: true

module Fang
  module Widgets
    class ClockWidget < BaseWidget
      widget_type 'clock'
      menu_label 'Add Clock'
      menu_icon "\u{1F550}"

      def self.header_title = 'Clock'
      def self.header_color = '#c084fc'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>'
      end

      def self.default_metadata = { 'timezone' => 'UTC', 'label' => 'UTC' }

      def render_content
        tz = @metadata['timezone'] || 'UTC'
        label = @metadata['label'] || tz
        <<~HTML
          <div class="flex flex-col items-center gap-1 py-2">
            <div class="text-xs font-medium" style="color:var(--muted-foreground)">#{label}</div>
            <div data-clock-display class="text-2xl font-mono font-semibold" style="color:var(--foreground)">--:--:--</div>
          </div>
        HTML
      end
    end
  end
end
