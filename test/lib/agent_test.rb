# frozen_string_literal: true

require_relative '../test_helper'

class AgentTest < Fang::TestCase
  def test_to_uuid_deterministic
    uuid1 = Fang::Agent.send(:to_uuid, 'test-session')
    uuid2 = Fang::Agent.send(:to_uuid, 'test-session')
    assert_equal uuid1, uuid2
  end

  def test_to_uuid_format
    uuid = Fang::Agent.send(:to_uuid, 'my-session')
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, uuid)
  end

  def test_to_uuid_different_inputs_differ
    uuid1 = Fang::Agent.send(:to_uuid, 'session-a')
    uuid2 = Fang::Agent.send(:to_uuid, 'session-b')
    refute_equal uuid1, uuid2
  end

  def test_parse_response_valid_json
    json = '{"result": "Hello world", "num_turns": 3, "total_cost_usd": 0.01}'
    result = Fang::Agent.send(:parse_response, json)

    assert_equal 'content', result['type']
    assert_equal 'Hello world', result['content']
    assert result['done']
  end

  def test_parse_response_empty_result_uses_content
    json = '{"result": "", "content": "Fallback content"}'
    result = Fang::Agent.send(:parse_response, json)
    assert_equal 'Fallback content', result['content']
  end

  def test_parse_response_empty_both_summarizes_tool_use
    json = '{"result": "", "content": "", "num_turns": 5, "total_cost_usd": 0.0234}'
    result = Fang::Agent.send(:parse_response, json)
    assert result['content'].include?('5 turn(s)')
    assert result['content'].include?('$0.0234')
  end

  def test_parse_response_empty_output
    result = Fang::Agent.send(:parse_response, '')
    assert_equal 'error', result['type']
    assert result['message'].include?('Empty response')
  end

  def test_parse_response_non_json
    result = Fang::Agent.send(:parse_response, 'plain text output')
    assert_equal 'content', result['type']
    assert_equal 'plain text output', result['content']
  end
end
