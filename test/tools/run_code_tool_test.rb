# frozen_string_literal: true

require_relative '../test_helper'

class RunCodeToolTest < Fang::ToolTestCase
  def test_execute_ruby
    tool = Fang::Tools::RunCodeTool.new
    result = tool.call(code: '2 + 2')

    assert_equal '4', result[:result]
  end

  def test_ruby_has_model_access
    Fang::Conversation.create!(title: 'Code Test', source: 'web')
    tool = Fang::Tools::RunCodeTool.new
    result = tool.call(code: 'Conversation.count')

    assert result[:result].to_i >= 1
  end

  def test_ruby_syntax_error
    tool = Fang::Tools::RunCodeTool.new
    result = tool.call(code: 'def foo(')

    refute result[:success]
    assert result[:error].include?('Syntax error')
  end

  def test_unsupported_language
    tool = Fang::Tools::RunCodeTool.new
    result = tool.call(code: 'print("hi")', language: 'go')

    refute result[:success]
    assert result[:error].include?('Unsupported language')
  end

  def test_python_delegates_to_runner
    tool = Fang::Tools::RunCodeTool.new
    fake_result = { success: true, result: '42' }

    original = Fang::PythonRunner.method(:run_code)
    Fang::PythonRunner.define_singleton_method(:run_code) { |*_args| fake_result }

    result = tool.call(code: '2 + 2', language: 'python')
    assert result[:success]
    assert_equal '42', result[:result]
  ensure
    Fang::PythonRunner.define_singleton_method(:run_code, original)
  end
end
