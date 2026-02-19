# frozen_string_literal: true

require_relative '../test_helper'

class SessionTest < Fang::TestCase
  def setup
    super
    @conversation = Fang::Conversation.create!(title: 'Test', source: 'web')
  end

  def test_valid_statuses
    %w[starting running stopped error].each do |status|
      s = Fang::Session.new(conversation: @conversation, status: status)
      assert s.valid?, "Expected status '#{status}' to be valid"
    end
  end

  def test_invalid_status
    s = Fang::Session.new(conversation: @conversation, status: 'dead')
    refute s.valid?
  end

  def test_start!
    s = Fang::Session.create!(conversation: @conversation, status: 'starting')
    s.start!
    assert s.running?
    refute_nil s.started_at
  end

  def test_stop!
    s = Fang::Session.create!(conversation: @conversation, status: 'running', started_at: Time.current)
    s.stop!
    assert s.stopped?
    refute_nil s.stopped_at
  end

  def test_error!
    s = Fang::Session.create!(conversation: @conversation, status: 'running', started_at: Time.current)
    s.error!
    assert s.error?
    refute_nil s.stopped_at
  end

  def test_duration
    started = 10.seconds.ago
    s = Fang::Session.create!(conversation: @conversation, status: 'stopped', started_at: started, stopped_at: Time.current)
    assert_in_delta 10.0, s.duration, 1.0
  end

  def test_duration_nil_without_started_at
    s = Fang::Session.new(conversation: @conversation, status: 'starting')
    assert_nil s.duration
  end

  def test_duration_uses_current_time_when_running
    s = Fang::Session.create!(conversation: @conversation, status: 'running', started_at: 5.seconds.ago)
    assert s.duration >= 4.0
  end

  def test_session_uuid_alias
    s = Fang::Session.new(conversation: @conversation, status: 'starting', container_id: 'abc-123')
    assert_equal 'abc-123', s.session_uuid
  end

  def test_active_scope
    Fang::Session.create!(conversation: @conversation, status: 'running', started_at: Time.current)
    Fang::Session.create!(conversation: @conversation, status: 'stopped')

    assert_equal 1, Fang::Session.active.count
  end
end
