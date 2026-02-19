# frozen_string_literal: true

module Fang
  module Widgets
    class ClockWidget < BaseWidget
      widget_type 'clock'
      menu_label 'Add Clock'
      menu_icon "\u{1F550}"

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
