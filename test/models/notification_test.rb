# frozen_string_literal: true

require_relative '../test_helper'

class NotificationTest < Fang::TestCase
  def test_title_required
    n = Fang::Notification.new(status: 'unread')
    refute n.valid?
    assert n.errors[:title].any?
  end

  def test_valid_kinds
    %w[info success warning error].each do |kind|
      n = Fang::Notification.new(title: 'Test', kind: kind, status: 'unread')
      assert n.valid?, "Expected kind '#{kind}' to be valid"
    end
  end

  def test_valid_statuses
    %w[unread read dismissed].each do |status|
      n = Fang::Notification.new(title: 'Test', kind: 'info', status: status)
      assert n.valid?, "Expected status '#{status}' to be valid"
    end
  end

  def test_mark_read!
    n = Fang::Notification.create!(title: 'Test', kind: 'info', status: 'unread')
    n.mark_read!
    assert_equal 'read', n.reload.status
  end

  def test_unread_scope
    Fang::Notification.create!(title: 'Unread', kind: 'info', status: 'unread')
    Fang::Notification.create!(title: 'Read', kind: 'info', status: 'read')

    assert_equal 1, Fang::Notification.unread.count
  end

  def test_start_conversation!
    n = Fang::Notification.create!(title: 'Alert', body: 'Something happened', kind: 'warning', status: 'unread')
    conv = n.start_conversation!

    assert_instance_of Fang::Conversation, conv
    assert conv.persisted?
    assert_equal 'Alert', conv.title
    assert_equal 'web', conv.source
    assert_equal 1, conv.messages.count
    assert conv.messages.first.content.include?('Alert')
  end
end
