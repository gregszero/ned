# frozen_string_literal: true

require_relative '../test_helper'

class ToolClassifierTest < Fang::TestCase
  ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'

  def setup
    super
    @original_key = ENV['ANTHROPIC_API_KEY']
    ENV['ANTHROPIC_API_KEY'] = 'test-key'
  end

  def teardown
    ENV['ANTHROPIC_API_KEY'] = @original_key
    super
  end

  # --- classify ---

  def test_classify_returns_groups
    stub_haiku_response('gmail, canvas')

    result = Fang::ToolClassifier.classify('Send an email and build a dashboard')
    assert_includes result, :core
    assert_includes result, :gmail
    assert_includes result, :canvas
  end

  def test_classify_returns_core_for_none
    stub_haiku_response('none')

    result = Fang::ToolClassifier.classify('Hello, how are you?')
    assert_equal [:core], result
  end

  def test_classify_filters_unknown_groups
    stub_haiku_response('gmail, bogus')

    result = Fang::ToolClassifier.classify('Check my email and do something weird')
    assert_includes result, :core
    assert_includes result, :gmail
    refute_includes result, :bogus
  end

  def test_classify_returns_nil_without_api_key
    ENV.delete('ANTHROPIC_API_KEY')

    result = Fang::ToolClassifier.classify('Send an email')
    assert_nil result
  end

  def test_classify_returns_nil_on_api_failure
    stub_request(:post, ANTHROPIC_URL).to_return(status: 500, body: 'Internal Server Error')

    result = Fang::ToolClassifier.classify('Send an email')
    assert_nil result
  end

  # --- groups_string ---

  def test_groups_string
    assert_equal 'core,gmail', Fang::ToolClassifier.groups_string([:core, :gmail])
  end

  def test_groups_string_nil
    assert_nil Fang::ToolClassifier.groups_string(nil)
  end

  # --- call_haiku ---

  def test_call_haiku_success
    stub_haiku_response('This is a summary.')

    result = Fang::ToolClassifier.call_haiku('Summarize this')
    assert_equal 'This is a summary.', result
  end

  def test_call_haiku_returns_nil_without_api_key
    ENV.delete('ANTHROPIC_API_KEY')

    result = Fang::ToolClassifier.call_haiku('Summarize this')
    assert_nil result
  end

  def test_call_haiku_returns_nil_on_failure
    stub_request(:post, ANTHROPIC_URL).to_return(status: 500, body: 'Error')

    result = Fang::ToolClassifier.call_haiku('Summarize this')
    assert_nil result
  end

  # --- build_context ---

  def test_build_context_with_conversation
    conv = Fang::Conversation.create!(title: 'Context Test', source: 'web')
    conv.add_message(role: 'user', content: 'Hello there')
    conv.add_message(role: 'assistant', content: 'Hi! How can I help?')

    stub_haiku_response('none')

    result = Fang::ToolClassifier.classify('Build me a page', conversation: conv)
    assert_equal [:core], result

    # Verify the request body included conversation context
    assert_requested(:post, ANTHROPIC_URL) do |req|
      body = JSON.parse(req.body)
      content = body['messages'][0]['content']
      content.include?('Recent conversation') && content.include?('Hello there')
    end
  end

  private

  def stub_haiku_response(text)
    stub_request(:post, ANTHROPIC_URL).to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: JSON.generate({
        content: [{ type: 'text', text: text }]
      })
    )
  end
end
