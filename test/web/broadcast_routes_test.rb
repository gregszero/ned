# frozen_string_literal: true

require_relative '../test_helper'

class BroadcastRoutesTest < Fang::RouteTestCase
  def setup
    super
    Fang::Web::TurboBroadcast.instance_variable_set(:@subscribers, Hash.new { |h, k| h[k] = [] })
  end

  def test_post_components_broadcasts_append
    page = Fang::Page.create!(title: 'Route Canvas', content: '', status: 'published', published_at: Time.current)

    captured = capture_broadcasts("canvas:#{page.id}") do
      post "/api/pages/#{page.id}/components",
        { component_type: 'card', content: '<p>route test</p>', x: 10, y: 20, width: 300 }.to_json,
        'CONTENT_TYPE' => 'application/json'
    end

    assert last_response.ok?
    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="append"'
    assert_includes html, "canvas-components-#{page.id}"
  end

  def test_delete_component_broadcasts_remove
    page = Fang::Page.create!(title: 'Route Canvas', content: '', status: 'published', published_at: Time.current)
    component = page.canvas_components.create!(
      component_type: 'card', content: '<p>bye</p>',
      x: 0, y: 0, width: 320, z_index: 0
    )

    captured = capture_broadcasts("canvas:#{page.id}") do
      delete "/api/pages/#{page.id}/components/#{component.id}"
    end

    assert last_response.ok?
    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="remove"'
    assert_includes html, "canvas-component-#{component.id}"
  end
end
