# frozen_string_literal: true

module Fang
  module Widgets
    class WorkflowMonitorWidget < BaseWidget
      widget_type 'workflow_monitor'
      menu_label 'Workflow Monitor'
      menu_icon "\u{1F504}"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval = 30
      def self.header_title     = 'Workflows'
      def self.header_color     = '#8b5cf6'

      STEP_COLORS = {
        'completed' => '#16a34a',
        'running'   => '#3b82f6',
        'failed'    => '#ef4444',
        'pending'   => '#71717a',
        'skipped'   => '#a1a1aa',
      }.freeze

      STATUS_BADGES = {
        'completed' => 'success',
        'running'   => 'info',
        'failed'    => 'error',
        'pending'   => '',
        'paused'    => 'warning',
      }.freeze

      def render_content
        workflows = Fang::Workflow.includes(:workflow_steps)
                                  .order(updated_at: :desc)
                                  .limit(5)
                                  .to_a

        if workflows.empty?
          return %(<div class="p-4 text-center text-sm text-fang-muted-fg">No workflows yet</div>)
        end

        html = +%(<div class="space-y-3 p-3">)
        workflows.each do |wf|
          html << render_workflow_row(wf)
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

      def render_workflow_row(wf)
        badge_class = STATUS_BADGES[wf.status] || ''
        steps = wf.workflow_steps.sort_by(&:position)

        html = +%(<div class="card p-2 space-y-2">)
        html << %(<div class="flex justify-between items-center gap-2">)
        html << %(<span class="text-sm font-semibold truncate">#{h wf.name}</span>)
        html << %(<span class="badge #{badge_class}" style="font-size:0.65rem">#{h wf.status}</span>)
        html << %(</div>)

        if steps.any?
          html << %(<div class="flex gap-0.5 h-2 rounded overflow-hidden">)
          steps.each do |step|
            color = STEP_COLORS[step.status] || STEP_COLORS['pending']
            tooltip = "#{h step.name} — #{step.status}"
            html << %(<div class="flex-1 rounded-sm" style="background:#{color}" title="#{tooltip}"></div>)
          end
          html << %(</div>)
        end

        html << %(</div>)
        html
      end
    end
  end
end
