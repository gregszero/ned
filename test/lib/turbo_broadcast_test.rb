# frozen_string_literal: true

require_relative '../test_helper'

class TurboBroadcastTest < Fang::TestCase
  def setup
    super
    reset_subscribers!
  end

  def teardown
    reset_subscribers!
    super
  end

  def test_subscribe_returns_the_block
    block = proc { |html| html }
    result = tb.subscribe('test-ch', &block)
    assert_equal block, result
  end

  def test_broadcast_delivers_to_subscribers
    received = []
    tb.subscribe('chat') { |html| received << html }

    tb.broadcast('chat', '<div>hello</div>')

    assert_equal ['<div>hello</div>'], received
  end

  def test_broadcast_delivers_to_multiple_subscribers
    a, b = [], []
    tb.subscribe('chat') { |html| a << html }
    tb.subscribe('chat') { |html| b << html }

    tb.broadcast('chat', 'msg')

    assert_equal ['msg'], a
    assert_equal ['msg'], b
  end

  def test_channel_isolation
    chat_msgs, notif_msgs = [], []
    tb.subscribe('chat') { |html| chat_msgs << html }
    tb.subscribe('notifications') { |html| notif_msgs << html }

    tb.broadcast('chat', 'chat-only')

    assert_equal ['chat-only'], chat_msgs
    assert_empty notif_msgs
  end

  def test_unsubscribe_stops_delivery
    received = []
    sub = tb.subscribe('chat') { |html| received << html }

    tb.broadcast('chat', 'before')
    tb.unsubscribe('chat', sub)
    tb.broadcast('chat', 'after')

    assert_equal ['before'], received
  end

  def test_error_isolation_between_subscribers
    good = []
    tb.subscribe('ch') { |_html| raise 'boom' }
    tb.subscribe('ch') { |html| good << html }

    tb.broadcast('ch', 'data')

    assert_equal ['data'], good
  end

  def test_broadcast_to_empty_channel_is_noop
    # Should not raise
    tb.broadcast('nobody-listening', 'hello')
  end

  private

  def tb
    Fang::Web::TurboBroadcast
  end

  def reset_subscribers!
    tb.instance_variable_set(:@subscribers, Hash.new { |h, k| h[k] = [] })
  end
end
