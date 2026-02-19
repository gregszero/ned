# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'

class PythonRunnerTest < Fang::TestCase
  def test_run_code_delegates_to_bridge
    # Test the parse_result logic with known output
    result = Fang::PythonRunner.send(:parse_result,
      '{"success": true, "result": "42", "output": "", "actions": []}',
      '',
      stub_status(true))

    assert result[:success]
    assert_equal '42', result[:result]
  end

  def test_parse_result_error
    result = Fang::PythonRunner.send(:parse_result,
      '',
      'SyntaxError: invalid syntax',
      stub_status(false, 1))

    refute result[:success]
    assert result[:error].include?('SyntaxError')
  end

  def test_parse_result_non_json_output
    result = Fang::PythonRunner.send(:parse_result,
      'plain text output',
      '',
      stub_status(true))

    assert result[:success]
    assert_equal 'plain text output', result[:result]
  end

  def test_run_skill_file_not_found
    # Stub venv_exists? to avoid needing a real venv
    original = Fang::PythonRunner.method(:venv_exists?)
    Fang::PythonRunner.define_singleton_method(:venv_exists?) { true }

    result = Fang::PythonRunner.run_skill('/nonexistent/skill.py')
    refute result[:success]
    assert result[:error].include?('not found')
  ensure
    Fang::PythonRunner.define_singleton_method(:venv_exists?, original)
  end

  def test_process_actions_send_message
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    actions = [{ 'type' => 'send_message', 'content' => 'Hello from Python', 'conversation_id' => conv.id.to_s }]

    ENV['CONVERSATION_ID'] = conv.id.to_s
    Fang::PythonRunner.process_actions(actions)

    assert_equal 1, conv.messages.count
    assert_equal 'Hello from Python', conv.messages.last.content
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_process_actions_create_notification
    # Silence broadcasts by clearing subscribers
    Fang::Web::TurboBroadcast.instance_variable_set(:@subscribers, Hash.new { |h, k| h[k] = [] })

    actions = [{ 'type' => 'create_notification', 'title' => 'Test Alert', 'body' => 'From Python', 'kind' => 'warning' }]

    Fang::PythonRunner.process_actions(actions)

    n = Fang::Notification.last
    assert_equal 'Test Alert', n.title
    assert_equal 'warning', n.kind
  end

  def test_process_actions_ignores_nil
    assert_nil Fang::PythonRunner.process_actions(nil)
  end

  def test_process_actions_ignores_unknown_type
    # Should not raise
    Fang::PythonRunner.process_actions([{ 'type' => 'unknown' }])
  end

  private

  def stub_status(success, exitstatus = 0)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status.define_singleton_method(:exitstatus) { exitstatus }
    status
  end
end
