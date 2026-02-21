# frozen_string_literal: true

require_relative '../test_helper'

class ConversationContextTest < Fang::TestCase
  def test_needs_summary_false_under_threshold
    conv = Fang::Conversation.create!(title: 'Short', source: 'web')
    5.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    refute conv.needs_summary?
  end

  def test_needs_summary_true_at_threshold
    conv = Fang::Conversation.create!(title: 'At Threshold', source: 'web')
    15.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    assert conv.needs_summary?
  end

  def test_needs_summary_false_after_recent_summary
    conv = Fang::Conversation.create!(title: 'Summarized', source: 'web')
    15.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }
    conv.update_columns(context_summary: 'A summary', summary_message_count: 15)

    refute conv.needs_summary?
  end

  def test_needs_summary_true_after_interval
    conv = Fang::Conversation.create!(title: 'Needs Re-summary', source: 'web')
    30.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }
    conv.update_columns(context_summary: 'Old summary', summary_message_count: 15)

    assert conv.needs_summary?
  end

  def test_compressed_prompt_with_summary
    conv = Fang::Conversation.create!(title: 'With Summary', source: 'web')
    conv.update_columns(context_summary: 'We discussed widgets.', summary_message_count: 20)

    result = conv.compressed_prompt('Build a chart')
    assert_includes result, 'CONVERSATION CONTEXT'
    assert_includes result, 'We discussed widgets.'
    assert_includes result, 'Build a chart'
    assert_includes result, '20 previous messages'
  end

  def test_compressed_prompt_without_summary
    conv = Fang::Conversation.create!(title: 'No Summary', source: 'web')

    result = conv.compressed_prompt('Hello')
    assert_equal 'Hello', result
  end

  def test_generate_summary_calls_haiku
    conv = Fang::Conversation.create!(title: 'Summarize Me', source: 'web')
    15.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    original = Fang::ToolClassifier.method(:call_haiku)
    Fang::ToolClassifier.define_singleton_method(:call_haiku) { |*_args, **_kwargs| 'Generated summary' }

    conv.generate_summary!
    conv.reload

    assert_equal 'Generated summary', conv.context_summary
    assert_equal 15, conv.summary_message_count
  ensure
    Fang::ToolClassifier.define_singleton_method(:call_haiku, original)
  end

  def test_generate_summary_skips_under_threshold
    conv = Fang::Conversation.create!(title: 'Too Short', source: 'web')
    5.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    original = Fang::ToolClassifier.method(:call_haiku)
    called = false
    Fang::ToolClassifier.define_singleton_method(:call_haiku) { |*_args, **_kwargs| called = true; 'Summary' }

    conv.generate_summary!
    refute called
    assert_nil conv.context_summary
  ensure
    Fang::ToolClassifier.define_singleton_method(:call_haiku, original)
  end

  def test_generate_summary_noop_when_haiku_returns_nil
    conv = Fang::Conversation.create!(title: 'Nil Haiku', source: 'web')
    15.times { |i| conv.add_message(role: 'user', content: "Message #{i}") }

    original = Fang::ToolClassifier.method(:call_haiku)
    Fang::ToolClassifier.define_singleton_method(:call_haiku) { |*_args, **_kwargs| nil }

    conv.generate_summary!
    conv.reload

    assert_nil conv.context_summary
  ensure
    Fang::ToolClassifier.define_singleton_method(:call_haiku, original)
  end
end
