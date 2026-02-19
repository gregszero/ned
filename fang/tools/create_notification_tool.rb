# frozen_string_literal: true

module Fang
  module Tools
    class CreateNotificationTool < FastMcp::Tool
      tool_name 'create_notification'
      description 'Create a notification for the user'

      arguments do
        required(:title).filled(:string).description('Notification title')
        required(:canvas_id).filled(:integer).description('The canvas (page) ID this notification belongs to')
        optional(:body).filled(:string).description('Notification body text')
        optional(:kind).filled(:string).description('Notification kind: info (default), success, warning, or error')
      end

      def call(title:, canvas_id:, body: nil, kind: 'info')
        notification = Notification.create!(
          title: title,
          body: body,
          kind: kind,
          status: 'unread',
          page_id: canvas_id
        )

        notification.broadcast!

        Fang.logger.info "Created #{kind} notification: #{title}"

        {
          success: true,
          notification_id: notification.id,
          title: notification.title,
          kind: notification.kind,
          canvas_id: notification.page_id
        }
      rescue => e
        Fang.logger.error "Failed to create notification: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
