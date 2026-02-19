# frozen_string_literal: true

module Fang
  module Widgets
    class BannerWidget < BaseWidget
      widget_type 'banner'
      menu_label 'Add Banner'
      menu_icon "\u{1F4E2}"

      def self.default_metadata
        { 'message' => 'Banner message', 'banner_type' => 'info' }
      end

      def render_content
        message = @metadata['message'] || 'Banner message'
        banner_type = @metadata['banner_type'] || 'info'

        colors = case banner_type
                 when 'success' then 'background:rgba(34,197,94,0.1);border-left:3px solid #22c55e;color:#22c55e'
                 when 'warning' then 'background:rgba(234,179,8,0.1);border-left:3px solid #eab308;color:#eab308'
                 when 'error'   then 'background:rgba(239,68,68,0.1);border-left:3px solid #ef4444;color:#ef4444'
                 else                'background:rgba(59,130,246,0.1);border-left:3px solid #3b82f6;color:#3b82f6'
                 end

        icon = case banner_type
               when 'success' then '&#10003;'
               when 'warning' then '&#9888;'
               when 'error'   then '&#10007;'
               else                '&#8505;'
               end

        <<~HTML
          <div class="flex items-center gap-3 p-4" style="#{colors};border-radius:var(--radius, 0.375rem)">
            <span class="text-lg">#{icon}</span>
            <div class="text-sm font-medium" style="color:var(--foreground)">#{h message}</div>
          </div>
        HTML
      end
    end
  end
end
