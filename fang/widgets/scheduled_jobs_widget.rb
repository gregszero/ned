# frozen_string_literal: true

module Fang
  module Widgets
    class ScheduledJobsWidget < BaseWidget
      widget_type 'scheduled_jobs'
      menu_label 'Jobs & Skills'
      menu_icon "\u{1F4CB}"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval  = 30

      def render_content
        tasks = Fang::ScheduledTask.order(scheduled_for: :desc)
        skills = Fang::SkillRecord.all.order(usage_count: :desc)

        html = +%(<div class="max-w-5xl mx-auto space-y-6">)
        html << %(<h2 class="text-2xl font-semibold tracking-tight">Jobs & Skills</h2>)

        # Scheduled Jobs
        html << %(<div class="card"><h3 class="section-heading">Scheduled Jobs (#{tasks.count})</h3>)
        if tasks.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Title</th><th>Scheduled For</th><th>Skill</th><th>Status</th><th>Result</th>)
          html << %(</tr></thead><tbody>)
          tasks.each do |task|
            status_badge = case task.status
                           when 'pending' then 'warning'
                           when 'running' then 'info'
                           when 'completed' then 'success'
                           when 'failed' then 'error'
                           else ''
                           end
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h task.title}</td>)
            html << %(<td>#{task.scheduled_for&.strftime('%b %d, %Y %H:%M')}</td>)
            html << %(<td>#{task.skill_name.present? ? "<code>#{h task.skill_name}</code>" : '<span class="text-ned-muted-fg">-</span>'}</td>)
            html << %(<td><span class="badge #{status_badge}">#{h task.status}</span></td>)
            html << %(<td class="max-w-xs truncate text-sm">#{h task.result}</td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No scheduled jobs yet.</p>)
        end
        html << %(</div>)

        # Skills
        html << %(<div class="card"><h3 class="section-heading">Skills (#{skills.count})</h3>)
        if skills.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Name</th><th>Description</th><th>Usage Count</th><th>File</th>)
          html << %(</tr></thead><tbody>)
          skills.each do |skill|
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h skill.name}</td>)
            html << %(<td>#{h skill.description}</td>)
            html << %(<td>#{skill.usage_count}</td>)
            html << %(<td><code>#{h skill.file_path}</code></td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No skills registered yet.</p>)
        end
        html << %(</div>)

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

      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end
    end
  end
end
