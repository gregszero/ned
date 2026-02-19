# frozen_string_literal: true

require_relative '../test_helper'

class CreatePageToolTest < Fang::ToolTestCase
  def test_creates_published_page
    tool = Fang::Tools::CreatePageTool.new
    result = tool.call(title: 'Test Page', content: '<h1>Hello</h1>')

    assert result[:success]
    assert_equal 'test-page', result[:slug]
    assert_equal 'published', result[:status]

    page = Fang::Page.find(result[:page_id])
    assert_equal 'Test Page', page.title
    assert page.published?
    refute_nil page.published_at
  end

  def test_creates_draft_page
    tool = Fang::Tools::CreatePageTool.new
    result = tool.call(title: 'Draft', content: '', status: 'draft')

    assert result[:success]
    assert_equal 'draft', result[:status]

    page = Fang::Page.find(result[:page_id])
    assert_nil page.published_at
  end

  def test_links_to_current_conversation
    conv = Fang::Conversation.create!(title: 'Active Conv', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::CreatePageTool.new
    result = tool.call(title: 'Linked Page', content: 'body')

    assert result[:success]
    assert_equal result[:page_id], conv.reload.page_id
  ensure
    ENV.delete('CONVERSATION_ID')
  end
end
