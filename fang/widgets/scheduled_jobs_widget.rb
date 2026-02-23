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

        # Triggers
        triggers = Fang::Trigger.order(:name)
        html << %(<div class="card"><h3 class="section-heading">Triggers (#{triggers.count})</h3>)
        if triggers.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Name</th><th>Event Pattern</th><th>Action</th><th>Enabled</th><th>Fire Count</th><th>Last Fired</th>)
          html << %(</tr></thead><tbody>)
          triggers.each do |trigger|
            enabled_badge = trigger.enabled? ? 'success' : 'error'
            enabled_label = trigger.enabled? ? 'Yes' : 'No'
            last_fired = trigger.last_fired_at&.strftime('%b %d, %Y %H:%M') || '-'
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h trigger.name}</td>)
            html << %(<td><code>#{h trigger.event_pattern}</code></td>)
            html << %(<td>#{h trigger.action_type}</td>)
            html << %(<td><span class="badge #{enabled_badge}">#{enabled_label}</span></td>)
            html << %(<td>#{trigger.fire_count}</td>)
            html << %(<td>#{last_fired}</td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No triggers configured yet.</p>)
        end
        html << %(</div>)

        # Workflows
        workflows = Fang::Workflow.order(created_at: :desc)
        html << %(<div class="card"><h3 class="section-heading">Workflows (#{workflows.count})</h3>)
        if workflows.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Name</th><th>Status</th><th>Current Step</th><th>Trigger Event</th><th>Steps</th><th>Created</th>)
          html << %(</tr></thead><tbody>)
          workflows.each do |wf|
            status_badge = case wf.status
                           when 'pending' then 'warning'
                           when 'running' then 'info'
                           when 'completed' then 'success'
                           when 'failed' then 'error'
                           when 'paused' then 'warning'
                           else ''
                           end
            step = wf.current_step
            step_label = step ? "#{step.position + 1}: #{h step.step_type}" : '-'
            trigger_event = wf.respond_to?(:trigger_event) && wf.trigger_event.present? ? h(wf.trigger_event) : '-'
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h wf.name}</td>)
            html << %(<td><span class="badge #{status_badge}">#{h wf.status}</span></td>)
            html << %(<td>#{step_label}</td>)
            html << %(<td>#{trigger_event}</td>)
            html << %(<td>#{wf.workflow_steps.count}</td>)
            html << %(<td>#{wf.created_at.strftime('%b %d, %Y %H:%M')}</td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No workflows yet.</p>)
        end
        html << %(</div>)

        # Active Widgets
        refreshable_types = Fang::Widgets::BaseWidget.registry.select { |_, klass| klass.refreshable? }.keys
        active_widgets = Fang::CanvasComponent.where(component_type: refreshable_types).includes(:page)
        html << %(<div class="card"><h3 class="section-heading">Active Widgets (#{active_widgets.count})</h3>)
        if active_widgets.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Widget Type</th><th>Page</th><th>Refresh Interval</th><th>Last Updated</th>)
          html << %(</tr></thead><tbody>)
          active_widgets.each do |comp|
            widget_class = Fang::Widgets::BaseWidget.for_type(comp.component_type)
            interval = widget_class&.refresh_interval
            interval_label = interval ? "#{interval}s" : '-'
            page_name = comp.page&.title || comp.page&.slug || '-'
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h comp.component_type}</td>)
            html << %(<td>#{h page_name}</td>)
            html << %(<td>#{interval_label}</td>)
            html << %(<td>#{comp.updated_at.strftime('%b %d, %Y %H:%M')}</td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No active widgets.</p>)
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
