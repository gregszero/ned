# frozen_string_literal: true

require_relative '../test_helper'

class HeartbeatTest < Fang::TestCase
  def create_heartbeat(**overrides)
    defaults = {
      name: "test-#{SecureRandom.hex(4)}",
      skill_name: 'check_health',
      frequency: 300,
      enabled: true,
      status: 'active',
      run_count: 0,
      error_count: 0
    }
    Fang::Heartbeat.create!(**defaults.merge(overrides))
  end

  def test_validations
    hb = Fang::Heartbeat.new(frequency: nil)
    refute hb.valid?
    assert hb.errors[:name].any?
    assert hb.errors[:skill_name].any?
    assert hb.errors[:frequency].any?
  end

  def test_name_uniqueness
    create_heartbeat(name: 'unique-hb')
    hb2 = Fang::Heartbeat.new(name: 'unique-hb', skill_name: 'test', frequency: 60)
    refute hb2.valid?
  end

  def test_frequency_must_be_positive
    hb = Fang::Heartbeat.new(name: 'test', skill_name: 'test', frequency: 0)
    refute hb.valid?
  end

  def test_due_now_when_never_run
    hb = create_heartbeat(last_run_at: nil)
    assert hb.due_now?
  end

  def test_due_now_when_frequency_elapsed
    hb = create_heartbeat(frequency: 60, last_run_at: 2.minutes.ago)
    assert hb.due_now?
  end

  def test_not_due_when_recently_run
    hb = create_heartbeat(frequency: 300, last_run_at: 1.minute.ago)
    refute hb.due_now?
  end

  def test_not_due_when_disabled
    hb = create_heartbeat(enabled: false, last_run_at: nil)
    refute hb.due_now?
  end

  def test_not_due_when_paused
    hb = create_heartbeat(status: 'paused', last_run_at: nil)
    refute hb.due_now?
  end

  def test_interpolated_prompt
    hb = create_heartbeat(prompt_template: 'Check {{name}}: {{result}} via {{skill_name}}')
    result = hb.interpolated_prompt('all good')
    assert_equal "Check #{hb.name}: all good via check_health", result
  end

  def test_interpolated_prompt_nil_without_template
    hb = create_heartbeat(prompt_template: nil)
    assert_nil hb.interpolated_prompt('result')
  end

  def test_record_run_success
    hb = create_heartbeat
    hb.record_run!(status: 'ok', result: 'healthy', duration_ms: 150)

    assert_equal 1, hb.heartbeat_runs.count
    assert_equal 1, hb.reload.run_count
    refute_nil hb.last_run_at
  end

  def test_record_run_error
    hb = create_heartbeat
    hb.record_run!(status: 'error', error: 'timeout')

    assert_equal 1, hb.reload.error_count
  end

  def test_frequency_label
    assert_equal '30s', create_heartbeat(frequency: 30).frequency_label
    assert_equal '5m', create_heartbeat(frequency: 300).frequency_label
    assert_equal '2h', create_heartbeat(frequency: 7200).frequency_label
  end

  def test_result_meaningful
    hb = create_heartbeat
    refute hb.result_meaningful?(nil)
    refute hb.result_meaningful?(false)
    refute hb.result_meaningful?('')
    refute hb.result_meaningful?([])
    assert hb.result_meaningful?('data')
    assert hb.result_meaningful?([1])
  end
end
