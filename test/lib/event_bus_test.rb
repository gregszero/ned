# frozen_string_literal: true

require_relative '../test_helper'

class EventBusTest < Fang::TestCase
  def test_emit_fires_matching_trigger
    trigger = Fang::Trigger.create!(
      name: 'Test Trigger',
      event_pattern: 'test:*',
      action_type: 'prompt',
      action_config: '{"prompt": "hello"}',
      enabled: true,
      fire_count: 0,
      consecutive_failures: 0
    )

    # Stub the job to track calls instead of actually executing
    job_called = false
    original = Fang::Jobs::TriggerRunnerJob.method(:perform_later)
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later) { |*_args| job_called = true }

    Fang::EventBus.emit('test:something', { data: 'value' })
    assert job_called, "Expected TriggerRunnerJob to be called"
  ensure
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later, original) if original
  end

  def test_emit_skips_disabled_trigger
    Fang::Trigger.create!(
      name: 'Disabled Trigger',
      event_pattern: 'test:*',
      action_type: 'prompt',
      action_config: '{}',
      enabled: false,
      fire_count: 0,
      consecutive_failures: 0
    )

    job_called = false
    original = Fang::Jobs::TriggerRunnerJob.method(:perform_later)
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later) { |*_args| job_called = true }

    Fang::EventBus.emit('test:something')
    refute job_called
  ensure
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later, original) if original
  end

  def test_emit_skips_non_matching_trigger
    Fang::Trigger.create!(
      name: 'Other Trigger',
      event_pattern: 'other:*',
      action_type: 'prompt',
      action_config: '{}',
      enabled: true,
      fire_count: 0,
      consecutive_failures: 0
    )

    job_called = false
    original = Fang::Jobs::TriggerRunnerJob.method(:perform_later)
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later) { |*_args| job_called = true }

    Fang::EventBus.emit('test:something')
    refute job_called
  ensure
    Fang::Jobs::TriggerRunnerJob.define_singleton_method(:perform_later, original) if original
  end

  def test_emit_starts_pending_workflow
    wf = Fang::Workflow.create!(
      name: 'Auto Workflow',
      status: 'pending',
      trigger_event: 'deploy:complete',
      current_step_index: 0
    )

    job_called = false
    original = Fang::Jobs::WorkflowRunnerJob.method(:perform_later)
    Fang::Jobs::WorkflowRunnerJob.define_singleton_method(:perform_later) { |*_args| job_called = true }

    Fang::EventBus.emit('deploy:complete')

    assert_equal 'running', wf.reload.status
    assert job_called
  ensure
    Fang::Jobs::WorkflowRunnerJob.define_singleton_method(:perform_later, original) if original
  end
end
