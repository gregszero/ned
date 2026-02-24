# frozen_string_literal: true

module Fang
  module Widgets
    class SystemOverviewWidget < BaseWidget
      widget_type 'system_overview'
      menu_label 'System Overview'
      menu_icon "\u{1F4CA}"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval = 60
      def self.header_title     = 'System Overview'
      def self.header_color     = '#16a34a'

      STATS = [
        { label: 'Conversations', model: 'Conversation', sub: nil },
        { label: 'Pages',         model: 'Page',         sub: -> { "#{Fang::Page.where(status: 'published').count} published" } },
        { label: 'Skills',        model: nil,             sub: nil, count: -> { Fang::SkillLoader.available_skills.size } },
        { label: 'Scheduled Jobs', model: 'ScheduledTask', sub: -> { "#{Fang::ScheduledTask.where(status: 'pending').count} pending" } },
        { label: 'Heartbeats',    model: 'Heartbeat',     sub: -> { "#{Fang::Heartbeat.where(enabled: true).count} active" } },
        { label: 'Workflows',     model: 'Workflow',      sub: -> { "#{Fang::Workflow.where(status: 'running').count} running" } },
        { label: 'Triggers',      model: 'Trigger',       sub: -> { "#{Fang::Trigger.where(enabled: true).count} active" } },
        { label: 'Notifications', model: 'Notification',  sub: -> { "#{Fang::Notification.where(status: 'unread').count} unread" } },
        { label: 'Data Tables',   model: 'DataTable',     sub: nil },
      ].freeze

      def render_content
        html = +%(<div class="grid grid-cols-3 gap-3 p-3">)

        STATS.each do |stat|
          count = if stat[:count]
                    stat[:count].call
                  elsif stat[:model]
                    Fang.const_get(stat[:model]).count
                  else
                    0
                  end

          sub_text = stat[:sub]&.call

          html << %(<div class="card p-3 text-center">)
          html << %(<div class="text-2xl font-bold" style="color:var(--foreground)">#{count}</div>)
          html << %(<div class="text-xs font-medium" style="color:var(--muted-foreground)">#{stat[:label]}</div>)
          if sub_text
            html << %(<div class="text-xs mt-1"><span class="badge info" style="font-size:0.65rem">#{sub_text}</span></div>)
          end
          html << %(</div>)
        end

        html << %(</div>)
        html
      end

      def refresh_data!
        new_content = render_content
        if new_content != @component.content
          @component.update!(content: new_content)
          true
        else
          false
        end
      end
    end
  end
end
