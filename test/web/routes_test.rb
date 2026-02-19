# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../web/app'

class RoutesTest < Fang::RouteTestCase
  def test_health_check
    get '/health'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 'ok', data['status']
    assert data['timestamp']
  end

  def test_root_redirects_to_published_page
    page = Fang::Page.create!(title: 'Home', content: '<h1>Home</h1>', status: 'published', published_at: Time.current)
    get '/'
    assert last_response.redirect?
    assert last_response.location.include?(page.slug)
  end

  def test_root_renders_home_when_no_pages
    get '/'
    assert last_response.ok?
  end

  def test_post_message_to_conversation
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')

    # Stub the job to avoid claude subprocess
    original = Fang::Jobs::AgentExecutorJob.method(:perform_later)
    Fang::Jobs::AgentExecutorJob.define_singleton_method(:perform_later) { |*_args| nil }

    post "/conversations/#{conv.id}/messages", content: 'New message'

    assert last_response.ok?
    assert_equal 1, conv.messages.count
    assert_equal 'New message', conv.messages.last.content
  ensure
    Fang::Jobs::AgentExecutorJob.define_singleton_method(:perform_later, original) if original
  end

  def test_post_empty_message_returns_400
    conv = Fang::Conversation.create!(title: 'Test', source: 'web')
    post "/conversations/#{conv.id}/messages", content: ''
    assert_equal 400, last_response.status
  end

  def test_page_by_slug
    page = Fang::Page.create!(title: 'My Page', content: '<p>Content</p>', status: 'published', published_at: Time.current)
    get "/pages/#{page.slug}"
    assert last_response.ok?
  end

  def test_api_conversations_list
    Fang::Conversation.create!(title: 'Conv A', source: 'web')
    Fang::Conversation.create!(title: 'Conv B', source: 'cli')

    get '/api/conversations'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 2, data['conversations'].size
  end

  def test_api_create_conversation
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    post '/api/conversations', title: 'New Conv', page_id: page.id.to_s
    assert last_response.ok?

    data = JSON.parse(last_response.body)
    assert_equal 'New Conv', data['title']
    assert data['slug']
  end

  def test_api_create_canvas
    post '/api/canvases', title: 'New Canvas'
    assert last_response.ok?

    data = JSON.parse(last_response.body)
    assert data['id']
    assert data['page_id']
    assert data['page_slug']
  end

  def test_mark_notification_read
    n = Fang::Notification.create!(title: 'Alert', kind: 'info', status: 'unread')
    post "/notifications/#{n.id}/read"
    assert last_response.ok?
    assert_equal 'read', n.reload.status
  end

  def test_canvas_slug_route
    page = Fang::Page.create!(title: 'Canvas Page', content: '<p>Canvas</p>', status: 'published', published_at: Time.current)
    get "/#{page.slug}"
    assert last_response.ok?
  end
end
