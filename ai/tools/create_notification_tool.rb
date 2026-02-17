# frozen_string_literal: true

module Ai
  module Tools
    class CreateNotificationTool < FastMcp::Tool
      tool_name 'create_notification'
      description 'Create a notification for the user'

      arguments do
        required(:title).filled(:string).description('Notification title')
        optional(:body).filled(:string).description('Notification body text')
        optional(:kind).filled(:string).description('Notification kind: info (default), success, warning, or error')
      end

      def call(title:, body: nil, kind: 'info')
        notification = Notification.create!(
          title: title,
          body: body,
          kind: kind,
          status: 'unread'
        )

        notification.broadcast!

        Ai.logger.info "Created #{kind} notification: #{title}"

        {
          success: true,
          notification_id: notification.id,
          title: notification.title,
          kind: notification.kind
        }
      rescue => e
        Ai.logger.error "Failed to create notification: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
