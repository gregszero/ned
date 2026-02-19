# frozen_string_literal: true

require_relative '../test_helper'

class HasJsonDefaultsTest < Fang::TestCase
  def test_json_defaults_on_new_record
    conv = Fang::Conversation.new(title: 'Test', source: 'web')
    assert_equal({}, conv.context)
  end

  def test_json_defaults_on_message
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    msg = Fang::Message.new(conversation: conv, role: 'user', content: 'hi')
    assert_equal({}, msg.metadata)
  end

  def test_does_not_override_explicit_value
    conv = Fang::Conversation.new(title: 'Test', source: 'web', context: { 'key' => 'val' })
    assert_equal({ 'key' => 'val' }, conv.context)
  end

  def test_scheduled_task_defaults
    task = Fang::ScheduledTask.new(title: 'Test', scheduled_for: 1.hour.from_now)
    assert_equal({}, task.parameters)
  end
end
