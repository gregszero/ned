# frozen_string_literal: true

require_relative '../test_helper'

class ToolGroupingTest < Fang::TestCase
  def test_default_group_is_core
    # A tool that includes ToolGrouping but never calls tool_group
    klass = Class.new(FastMcp::Tool) do
      include Fang::Concerns::ToolGrouping
      tool_name 'test_default'
      description 'Test tool'
    end

    assert_equal :core, klass.tool_group
  end

  def test_custom_group
    klass = Class.new(FastMcp::Tool) do
      include Fang::Concerns::ToolGrouping
      tool_name 'test_custom'
      description 'Test tool'
      tool_group :gmail
    end

    assert_equal :gmail, klass.tool_group
  end

  def test_gmail_tools_have_gmail_group
    assert_equal :gmail, Fang::Tools::GmailSearchTool.tool_group
  end

  def test_run_code_has_core_group
    assert_equal :core, Fang::Tools::RunCodeTool.tool_group
  end

  def test_build_canvas_has_canvas_group
    assert_equal :canvas, Fang::Tools::BuildCanvasTool.tool_group
  end
end
