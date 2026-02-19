# frozen_string_literal: true

require_relative '../test_helper'

class ConversationTest < Fang::TestCase
  def test_valid_sources
    %w[web cli scheduled_task whatsapp heartbeat].each do |source|
      conv = Fang::Conversation.new(title: 'Test', source: source)
      assert conv.valid?, "Expected source '#{source}' to be valid"
    end
  end

  def test_invalid_source
    conv = Fang::Conversation.new(title: 'Test', source: 'invalid')
    refute conv.valid?
    assert conv.errors[:source].any?
  end

  def test_source_required
    conv = Fang::Conversation.new(title: 'Test', source: nil)
    refute conv.valid?
  end

  def test_add_message
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    msg = conv.add_message(role: 'user', content: 'Hello')

    assert_instance_of Fang::Message, msg
    assert msg.persisted?
    assert_equal 'user', msg.role
    assert_equal 'Hello', msg.content
    assert_equal 1, conv.messages.count
  end

  def test_add_message_touches_last_message_at
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    original = conv.last_message_at
    sleep 0.01
    conv.add_message(role: 'user', content: 'Hello')
    conv.reload
    assert conv.last_message_at >= original
  end

  def test_generate_slug
    conv = Fang::Conversation.create!(title: 'My Great Chat', source: 'web')
    assert_equal 'my-great-chat', conv.slug
  end

  def test_generate_slug_uniqueness
    Fang::Conversation.create!(title: 'Same Title', source: 'web')
    conv2 = Fang::Conversation.create!(title: 'Same Title', source: 'web')
    assert_equal 'same-title-1', conv2.slug
  end

  def test_generate_slug_without_title
    conv = Fang::Conversation.create!(source: 'web')
    assert conv.slug.start_with?('chat-')
  end

  def test_slug_uniqueness_validation
    Fang::Conversation.create!(title: 'Test', source: 'web', slug: 'my-slug')
    conv = Fang::Conversation.new(title: 'Test 2', source: 'web', slug: 'my-slug')
    refute conv.valid?
  end

  def test_latest_messages
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    5.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    msgs = conv.latest_messages(3)
    assert_equal 3, msgs.size
    assert_equal 'Message 2', msgs.first.content
  end

  def test_default_context
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    assert_equal({}, conv.context)
  end

  def test_recent_scope
    old = Fang::Conversation.create!(title: 'Old', source: 'web', last_message_at: 1.day.ago)
    new_conv = Fang::Conversation.create!(title: 'New', source: 'web', last_message_at: Time.current)

    result = Fang::Conversation.recent
    assert_equal new_conv.id, result.first.id
  end
end
