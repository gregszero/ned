# frozen_string_literal: true

module Fang
  module Tools
    class CreateApprovalTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'create_approval'
      description 'Create a standalone approval request. Sends a notification and optionally schedules an expiry timeout.'
      tool_group :automation

      arguments do
        required(:title).filled(:string).description('Approval title')
        optional(:description).filled(:string).description('Context for the approver')
        optional(:timeout).filled(:string).description('Auto-expire after duration (e.g. "30 minutes", "2 hours")')
        optional(:canvas_id).filled(:integer).description('Page/canvas ID to link the approval to')
        optional(:metadata).description('Additional JSON metadata')
      end

      def call(title:, description: nil, timeout: nil, canvas_id: nil, metadata: nil)
        notification = Notification.create!(
          title: "Approval needed: #{title}",
          body: description || title,
          kind: 'warning',
          page_id: canvas_id
        )
        notification.broadcast!

        approval = Approval.create!(
          title: title,
          description: description,
          notification: notification,
          page_id: canvas_id,
          metadata: metadata&.to_json
        )

        # Schedule expiry if timeout given
        if timeout
          duration = parse_duration(timeout)
          if duration
            ScheduledTask.create!(
              title: "Expire approval: #{title}",
              scheduled_for: duration.from_now,
              description: "approval_expire:#{approval.id}"
            )
          end
        end

        {
          success: true,
          approval_id: approval.id,
          title: approval.title,
          notification_id: notification.id,
          status: 'pending'
        }
      rescue => e
        { success: false, error: e.message }
      end

      private

      def parse_duration(str)
        return nil unless str
        case str
        when /^(\d+)\s*seconds?$/ then $1.to_i.seconds
        when /^(\d+)\s*minutes?$/ then $1.to_i.minutes
        when /^(\d+)\s*hours?$/ then $1.to_i.hours
        when /^(\d+)\s*days?$/ then $1.to_i.days
        end
      end
    end
  end
end
