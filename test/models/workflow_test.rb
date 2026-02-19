# frozen_string_literal: true

require_relative '../test_helper'

class WorkflowTest < Fang::TestCase
  def create_workflow(**overrides)
    defaults = { name: 'Test Workflow', status: 'pending', current_step_index: 0 }
    Fang::Workflow.create!(**defaults.merge(overrides))
  end

  def test_validations
    wf = Fang::Workflow.new
    refute wf.valid?
    assert wf.errors[:name].any?
  end

  def test_valid_statuses
    %w[pending running completed failed paused].each do |status|
      wf = Fang::Workflow.new(name: 'Test', status: status)
      assert wf.valid?, "Expected status '#{status}' to be valid"
    end
  end

  def test_parsed_context
    wf = create_workflow(context: '{"key":"value"}')
    assert_equal({ 'key' => 'value' }, wf.parsed_context)
  end

  def test_parsed_context_blank
    wf = create_workflow(context: nil)
    assert_equal({}, wf.parsed_context)
  end

  def test_parsed_context_invalid_json
    wf = create_workflow(context: 'bad json')
    assert_equal({}, wf.parsed_context)
  end

  def test_merge_context!
    wf = create_workflow(context: '{"a":1}')
    wf.merge_context!('b' => 2)
    assert_equal({ 'a' => 1, 'b' => 2 }, wf.parsed_context)
  end

  def test_complete!
    wf = create_workflow(status: 'running')
    wf.complete!
    assert wf.completed?
  end

  def test_fail!
    wf = create_workflow(status: 'running')
    wf.fail!('something broke')
    assert wf.failed?
  end

  def test_pause!
    wf = create_workflow(status: 'running')
    wf.pause!
    assert wf.paused?
  end

  def test_advance_completes_when_no_more_steps
    wf = create_workflow(status: 'running', current_step_index: 0)
    # No steps exist, so advancing should complete the workflow
    wf.advance!
    assert_equal 1, wf.current_step_index
    assert wf.completed?
  end

  def test_ensure_conversation!
    wf = create_workflow
    conv = wf.ensure_conversation!
    assert_instance_of Fang::Conversation, conv
    assert conv.persisted?
    assert_equal wf.reload.conversation_id, conv.id
  end

  def test_ensure_conversation_returns_existing
    conv = Fang::Conversation.create!(title: 'Existing', source: 'scheduled_task')
    wf = create_workflow(conversation: conv)
    assert_equal conv.id, wf.ensure_conversation!.id
  end
end
