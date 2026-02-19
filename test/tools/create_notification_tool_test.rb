# frozen_string_literal: true

require_relative '../test_helper'

class CreateNotificationToolTest < Fang::ToolTestCase
  def test_creates_notification
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    tool = Fang::Tools::CreateNotificationTool.new

    result = tool.call(title: 'Test Alert', canvas_id: page.id, body: 'Something happened', kind: 'warning')

    assert result[:success]
    assert result[:notification_id]

    notification = Fang::Notification.find(result[:notification_id])
    assert_equal 'Test Alert', notification.title
    assert_equal 'warning', notification.kind
    assert_equal page.id, notification.page_id
  end

  def test_default_kind
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    tool = Fang::Tools::CreateNotificationTool.new

    result = tool.call(title: 'Info Alert', canvas_id: page.id)
    notification = Fang::Notification.find(result[:notification_id])
    assert_equal 'info', notification.kind
  end

  def test_handles_error
    tool = Fang::Tools::CreateNotificationTool.new
    # Missing required canvas_id with an invalid value
    result = tool.call(title: '', canvas_id: 0)
    refute result[:success]
  end
end
