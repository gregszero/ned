# frozen_string_literal: true

module Fang
  module Widgets
    class QuickActionsWidget < BaseWidget
      widget_type 'quick_actions'
      menu_label 'Quick Actions'
      menu_icon "\u26A1"
      menu_category 'System'

      def self.header_title = 'Quick Actions'
      def self.header_color = '#f59e0b'

      DEFAULT_ACTIONS = [
        { label: 'Daily Briefing',    skill: 'daily_briefing',    icon: "\u2600\uFE0F" },
        { label: 'Check Gmail',       skill: 'check_gmail',       icon: "\u{1F4E7}" },
        { label: 'List Heartbeats',   skill: 'list_heartbeats',   icon: "\u{1F49A}" },
        { label: 'Pending Approvals', skill: 'pending_approvals', icon: "\u2705" },
      ].freeze

      def render_content
        actions = @metadata['actions'] || DEFAULT_ACTIONS.map { |a| a.transform_keys(&:to_s) }

        html = +%(<div class="grid grid-cols-2 gap-2 p-3">)
        actions.each do |action|
          icon = action['icon'] || "\u26A1"
          label = h(action['label'] || action['skill'])
          skill = action['skill']
          action_json = %({ "action_type": "run_skill", "skill_name": "#{skill}" }).gsub('"', '&quot;')

          html << %(<button class="outline sm w-full text-left" )
          html << %(data-fang-action="#{action_json}" )
          html << %(data-loading-text="Running..." data-success-text="Done">)
          html << %(<span class="mr-1">#{icon}</span> #{label})
          html << %(</button>)
        end
        html << %(</div>)
        html
      end
    end
  end
end
