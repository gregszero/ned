# frozen_string_literal: true

require_relative '../test_helper'

class MessageTest < Fang::TestCase
  def setup
    super
    @conversation = Fang::Conversation.create!(title: 'Test', source: 'web')
  end

  def test_valid_roles
    %w[user assistant system].each do |role|
      msg = Fang::Message.new(conversation: @conversation, role: role, content: 'hi')
      assert msg.valid?, "Expected role '#{role}' to be valid"
    end
  end

  def test_invalid_role
    msg = Fang::Message.new(conversation: @conversation, role: 'admin', content: 'hi')
    refute msg.valid?
  end

  def test_content_required
    msg = Fang::Message.new(conversation: @conversation, role: 'user')
    refute msg.valid?
  end

  def test_role_predicates
    user_msg = Fang::Message.new(conversation: @conversation, role: 'user', content: 'hi')
    assert user_msg.user?
    refute user_msg.assistant?
    refute user_msg.system?

    ai_msg = Fang::Message.new(conversation: @conversation, role: 'assistant', content: 'hi')
    assert ai_msg.assistant?
    refute ai_msg.user?
  end

  def test_truncated_content_short
    msg = Fang::Message.new(conversation: @conversation, role: 'user', content: 'short')
    assert_equal 'short', msg.truncated_content
  end

  def test_truncated_content_long
    content = 'a' * 200
    msg = Fang::Message.new(conversation: @conversation, role: 'user', content: content)
    truncated = msg.truncated_content(100)
    assert_equal 103, truncated.length
    assert truncated.end_with?('...')
  end

  def test_scopes
    @conversation.add_message(role: 'user', content: 'Hello')
    @conversation.add_message(role: 'assistant', content: 'Hi there')
    @conversation.add_message(role: 'system', content: 'Note')

    assert_equal 1, Fang::Message.user_messages.count
    assert_equal 1, Fang::Message.assistant_messages.count
    assert_equal 1, Fang::Message.system_messages.count
  end

  def test_default_metadata
    msg = Fang::Message.new(conversation: @conversation, role: 'user', content: 'hi')
    assert_equal({}, msg.metadata)
  end
end
