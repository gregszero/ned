# frozen_string_literal: true

module Ai
  module Tools
    class CreateNotificationTool < FastMcp::Tool
      tool_name 'create_notification'
      description 'Create a notification for the user'

      arguments do
        required(:title).filled(:string).description('Notification title')
        required(:canvas_id).filled(:integer).description('The canvas (ai_page) ID this notification belongs to')
        optional(:body).filled(:string).description('Notification body text')
        optional(:kind).filled(:string).description('Notification kind: info (default), success, warning, or error')
      end

      def call(title:, canvas_id:, body: nil, kind: 'info')
        notification = Notification.create!(
          title: title,
          body: body,
          kind: kind,
          status: 'unread',
          ai_page_id: canvas_id
        )

        notification.broadcast!

        Ai.logger.info "Created #{kind} notification: #{title}"

        {
          success: true,
          notification_id: notification.id,
          title: notification.title,
          kind: notification.kind,
          canvas_id: notification.ai_page_id
        }
      rescue => e
        Ai.logger.error "Failed to create notification: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
