# frozen_string_literal: true

require_relative '../test_helper'

class TriggerTest < Fang::TestCase
  def test_validations
    t = Fang::Trigger.new
    refute t.valid?
    assert t.errors[:name].any?
    assert t.errors[:event_pattern].any?
    assert t.errors[:action_type].any?
  end

  def test_valid_action_types
    %w[skill prompt].each do |type|
      t = Fang::Trigger.new(name: 'Test', event_pattern: 'test:*', action_type: type, action_config: '{}')
      assert t.valid?, "Expected action_type '#{type}' to be valid"
    end
  end

  def test_invalid_action_type
    t = Fang::Trigger.new(name: 'Test', event_pattern: 'test:*', action_type: 'webhook')
    refute t.valid?
  end

  def test_matches_exact
    t = Fang::Trigger.new(event_pattern: 'task:completed:daily_check')
    assert t.matches?('task:completed:daily_check')
    refute t.matches?('task:completed:other')
  end

  def test_matches_wildcard
    t = Fang::Trigger.new(event_pattern: 'task:completed:*')
    assert t.matches?('task:completed:daily_check')
    assert t.matches?('task:completed:weekly')
    refute t.matches?('task:failed:daily_check')
  end

  def test_matches_double_wildcard
    t = Fang::Trigger.new(event_pattern: 'notification:*')
    assert t.matches?('notification:created:info')
  end

  def test_parsed_config
    t = Fang::Trigger.new(action_config: '{"skill_name": "test"}')
    assert_equal({ 'skill_name' => 'test' }, t.parsed_config)
  end

  def test_parsed_config_blank
    t = Fang::Trigger.new(action_config: nil)
    assert_equal({}, t.parsed_config)
  end

  def test_parsed_config_invalid_json
    t = Fang::Trigger.new(action_config: 'not json')
    assert_equal({}, t.parsed_config)
  end

  def test_record_failure_increments
    t = Fang::Trigger.create!(name: 'Test', event_pattern: 'test:*', action_type: 'prompt', action_config: '{}', enabled: true, fire_count: 0, consecutive_failures: 0)
    t.record_failure!
    assert_equal 1, t.reload.consecutive_failures
    assert t.enabled?
  end

  def test_record_failure_disables_after_five
    t = Fang::Trigger.create!(name: 'Test', event_pattern: 'test:*', action_type: 'prompt', action_config: '{}', enabled: true, fire_count: 0, consecutive_failures: 4)
    t.record_failure!
    assert_equal 5, t.reload.consecutive_failures
    refute t.enabled?
  end

  def test_enabled_scope
    Fang::Trigger.create!(name: 'Enabled', event_pattern: 'test:*', action_type: 'prompt', action_config: '{}', enabled: true, fire_count: 0, consecutive_failures: 0)
    Fang::Trigger.create!(name: 'Disabled', event_pattern: 'test:*', action_type: 'prompt', action_config: '{}', enabled: false, fire_count: 0, consecutive_failures: 0)

    assert_equal 1, Fang::Trigger.enabled.count
  end
end
