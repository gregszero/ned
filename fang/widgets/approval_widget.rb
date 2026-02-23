# frozen_string_literal: true

module Fang
  module Widgets
    class ApprovalWidget < BaseWidget
      widget_type 'approval'
      menu_label 'Approvals'
      menu_icon "\u2705"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval = 30
      def self.header_title     = 'Pending Approvals'
      def self.header_color     = '#f59e0b'

      def render_content
        approvals = Fang::Approval.pending.recent.limit(20).to_a

        html = +%(<div class="space-y-3 p-3">)

        if approvals.any?
          approvals.each do |a|
            html << render_approval_card(a)
          end
        else
          html << %(<p class="text-sm text-fang-muted-fg text-center py-4">No pending approvals</p>)
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

      def render_approval_card(approval)
        html = +%(<div class="card p-3 space-y-2">)
        html << %(<div class="font-semibold text-sm">#{h approval.title}</div>)
        if approval.description.present?
          html << %(<p class="text-xs text-fang-muted-fg">#{h approval.description}</p>)
        end
        html << %(<div class="text-xs text-fang-muted-fg">#{approval.created_at.strftime('%b %d, %H:%M')}</div>)
        html << %(<div class="flex gap-2 pt-1">)
        html << %(<button class="xs" data-fang-action='{"action_type":"resolve_approval","approval_id":#{approval.id},"decision":"approve"}' data-loading-text="..." data-success-text="Approved">Approve</button>)
        html << %(<button class="outline xs" data-fang-action='{"action_type":"resolve_approval","approval_id":#{approval.id},"decision":"reject"}' data-loading-text="..." data-success-text="Rejected">Reject</button>)
        html << %(</div>)
        html << %(</div>)
        html
      end
    end
  end
end
