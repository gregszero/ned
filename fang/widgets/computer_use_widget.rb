# frozen_string_literal: true

module Fang
  module Widgets
    class ComputerUseWidget < BaseWidget
      widget_type :computer_use
      menu_category 'System'

      def self.header_title = 'Computer Use'
      def self.header_color = '#60a5fa'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>'
      end

      def render_content
        status = @metadata['status'] || 'running'
        last_action = @metadata['last_action']
        screenshot_data = @metadata['screenshot']

        status_class = case status
                       when 'running' then 'cua-status-running'
                       when 'stopped' then 'cua-status-stopped'
                       when 'error'   then 'cua-status-error'
                       else ''
                       end

        img_html = if screenshot_data && !screenshot_data.empty?
          %(<img id="cua-screen-#{@component.id}" class="cua-screen" src="data:image/png;base64,#{screenshot_data}" alt="Computer screen" />)
        else
          %(<div id="cua-screen-#{@component.id}" class="cua-screen cua-screen-placeholder"><span>Starting display...</span></div>)
        end

        action_html = if last_action
          %(<div class="cua-action-bar"><span class="cua-action-label">#{h(last_action)}</span></div>)
        else
          ""
        end

        <<~HTML
          <div class="cua-container">
            <div class="cua-status #{status_class}">#{h(status)}</div>
            #{img_html}
            #{action_html}
          </div>
        HTML
      end
    end
  end
end
