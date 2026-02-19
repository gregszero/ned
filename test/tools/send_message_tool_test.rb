# frozen_string_literal: true

require_relative '../test_helper'

class SendMessageToolTest < Fang::ToolTestCase
  def test_sends_message_to_conversation
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    # Ensure canvas exists for broadcast_channel
    conv.ensure_canvas!

    tool = Fang::Tools::SendMessageTool.new
    result = tool.call(content: 'Hello from tool', conversation_id: conv.id)

    assert result[:success]
    assert_equal conv.id, result[:conversation_id]

    msg = Fang::Message.find(result[:message_id])
    assert_equal 'assistant', msg.role
    assert_equal 'Hello from tool', msg.content
  end

  def test_uses_env_conversation_id
    conv = Fang::Conversation.create!(title: 'ENV Conv', source: 'web')
    conv.ensure_canvas!
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::SendMessageTool.new
    result = tool.call(content: 'Via ENV')

    assert result[:success]
    assert_equal conv.id, result[:conversation_id]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_no_conversation_found
    # Remove all conversations, clear ENV
    ENV.delete('CONVERSATION_ID')
    Fang::Conversation.destroy_all

    tool = Fang::Tools::SendMessageTool.new
    result = tool.call(content: 'Orphan message')

    refute result[:success]
    assert result[:error].include?('No conversation')
  end
end
