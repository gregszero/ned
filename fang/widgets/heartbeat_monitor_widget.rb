# frozen_string_literal: true

module Fang
  module Widgets
    class HeartbeatMonitorWidget < BaseWidget
      widget_type 'heartbeat_monitor'
      menu_label 'Heartbeat Monitor'
      menu_icon "\u{1F49A}"

      def self.refreshable?     = true
      def self.refresh_interval  = 30

      def render_content
        heartbeats = Fang::Heartbeat.order(:name).to_a

        html = +%(<div class="max-w-5xl mx-auto space-y-6">)
        html << %(<h2 class="text-2xl font-semibold tracking-tight">Heartbeats</h2>)

        if heartbeats.any?
          html << render_grid(heartbeats)
          html << render_summary(heartbeats)
        else
          html << %(<div class="card"><p class="text-ned-muted-fg">No heartbeats configured yet. Use <code>create_heartbeat</code> to add one.</p></div>)
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

      private

      def render_grid(heartbeats)
        html = +%(<div class="card hb-grid">)
        html << %(<div class="overflow-x-auto">)
        html << %(<table><thead><tr>)
        html << %(<th>Heartbeat</th><th>Skill</th><th>Freq</th><th>Status</th><th class="text-right">Recent Runs</th>)
        html << %(</tr></thead><tbody>)

        heartbeats.each do |hb|
          runs = hb.recent_runs(30).to_a.reverse # oldest first for left-to-right display

          status_badge = case hb.status
                         when 'active' then hb.enabled? ? 'success' : 'warning'
                         when 'paused' then 'warning'
                         when 'error' then 'error'
                         else ''
                         end
          status_label = hb.enabled? ? hb.status : 'disabled'

          html << %(<tr>)
          html << %(<td class="font-semibold">)
          html << %(#{h hb.name})
          if hb.description.present?
            html << %(<br><span class="text-xs text-ned-muted-fg">#{h hb.description}</span>)
          end
          html << %(</td>)
          html << %(<td><code>#{h hb.skill_name}</code></td>)
          html << %(<td>#{h hb.frequency_label}</td>)
          html << %(<td>)
          html << %(<span class="badge #{status_badge}">#{h status_label}</span>)
          html << %( <button class="ghost xs" data-ned-action='{"action_type":"toggle_heartbeat","heartbeat_id":#{hb.id}}' )
          html << %(data-loading-text="..." data-success-text="Done">)
          html << %(#{hb.enabled? ? 'Pause' : 'Resume'}</button>)
          html << %(</td>)
          html << %(<td class="text-right">)
          html << render_run_cells(runs)
          html << %(</td>)
          html << %(</tr>)
        end

        html << %(</tbody></table></div>)
        html << %(</div>)
        html
      end

      def render_run_cells(runs)
        return %(<span class="text-xs text-ned-muted-fg">No runs yet</span>) if runs.empty?

        html = +%(<div class="flex gap-0.5 justify-end flex-wrap">)
        runs.each do |run|
          css_class = case run.status
                      when 'success' then 'hb-cell success'
                      when 'skipped' then 'hb-cell skipped'
                      when 'error' then 'hb-cell error'
                      else 'hb-cell'
                      end
          tooltip = "#{run.ran_at.strftime('%H:%M:%S')} — #{run.status}"
          tooltip += " (escalated)" if run.escalated?
          tooltip += ": #{run.error_message}" if run.error_message.present?
          html << %(<div class="#{css_class}" title="#{h tooltip}"></div>)
        end
        html << %(</div>)
        html
      end

      def render_summary(heartbeats)
        today_runs = Fang::HeartbeatRun.where('ran_at >= ?', Time.current.beginning_of_day)
        total_today = today_runs.count
        errors_today = today_runs.where(status: 'error').count
        skipped_today = today_runs.where(status: 'skipped').count
        error_rate = total_today > 0 ? ((errors_today.to_f / total_today) * 100).round(1) : 0

        html = +%(<div class="card">)
        html << %(<div class="flex gap-6 text-sm">)
        html << %(<div><span class="text-ned-muted-fg">Runs today:</span> <strong>#{total_today}</strong></div>)
        html << %(<div><span class="text-ned-muted-fg">Errors:</span> <strong>#{errors_today}</strong> <span class="text-ned-muted-fg">(#{error_rate}%)</span></div>)
        html << %(<div><span class="text-ned-muted-fg">Skipped (tokens saved):</span> <strong>#{skipped_today}</strong></div>)
        html << %(</div>)
        html << %(</div>)
        html
      end
    end
  end
end
