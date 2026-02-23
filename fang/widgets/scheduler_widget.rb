# frozen_string_literal: true

module Fang
  module Widgets
    class SchedulerWidget < BaseWidget
      widget_type 'scheduler'
      menu_label 'Scheduler Timers'
      menu_icon "\u{23F1}"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval = 60
      def self.header_title     = 'Scheduler'

      def render_content
        jobs = Fang::Scheduler.jobs

        html = +%(<div class="overflow-x-auto"><table><thead><tr>)
        html << %(<th>Name</th><th>Interval</th><th>Last Fired</th><th>Next Fire</th><th>Status</th>)
        html << %(</tr></thead><tbody>)

        if jobs.any?
          jobs.each do |job|
            status_badge = job[:status] == 'running' ? 'success' : 'warning'
            last_fired = job[:last_fired_at]&.strftime('%b %d, %H:%M:%S') || '-'
            next_fire = job[:next_fire_at]&.strftime('%b %d, %H:%M:%S') || '-'

            html << %(<tr>)
            html << %(<td class="font-semibold">#{h job[:name]}</td>)
            html << %(<td><code>#{h job[:interval]}</code></td>)
            html << %(<td>#{h last_fired}</td>)
            html << %(<td>#{h next_fire}</td>)
            html << %(<td><span class="badge #{status_badge}">#{h job[:status]}</span></td>)
            html << %(</tr>)
          end
        else
          html << %(<tr><td colspan="5" class="text-fang-muted-fg">Scheduler not running.</td></tr>)
        end

        html << %(</tbody></table></div>)
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
