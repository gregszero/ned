# frozen_string_literal: true

require_relative '../test_helper'

class BroadcastIntegrationTest < Fang::TestCase
  def setup
    super
    # Start with clean subscribers for capture_broadcasts
    Fang::Web::TurboBroadcast.instance_variable_set(:@subscribers, Hash.new { |h, k| h[k] = [] })
  end

  # --- Notification#broadcast! ---

  def test_notification_broadcast_sends_prepend_and_replace
    page = Fang::Page.create!(title: 'Test', content: '', status: 'published', published_at: Time.current)
    notification = Fang::Notification.create!(title: 'Alert', kind: 'info', status: 'unread', page: page)

    captured = capture_broadcasts('notifications') do
      notification.broadcast!
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="prepend"'
    assert_includes html, 'target="notifications-list"'
    assert_includes html, 'action="replace"'
    assert_includes html, 'target="notifications-badge"'
    assert_includes html, 'Alert'
  end

  # --- SendMessageTool ---

  def test_send_message_tool_broadcasts_remove_thinking_and_append_message
    page = Fang::Page.create!(title: 'Chat Page', content: '', status: 'published', published_at: Time.current)
    conversation = Fang::Conversation.create!(title: 'Test Chat', source: 'web', page: page)

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::SendMessageTool.new
      tool.call(content: 'Hello world', conversation_id: conversation.id)
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="remove"'
    assert_includes html, "thinking-indicator-#{conversation.id}"
    assert_includes html, 'action="append"'
    assert_includes html, "messages-#{conversation.id}"
    assert_includes html, 'Hello world'
  end

  # --- AddCanvasComponentTool ---

  def test_add_canvas_component_tool_broadcasts_append
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    conversation = Fang::Conversation.create!(title: 'Test', source: 'web', page: page)

    ENV['PAGE_ID'] = page.id.to_s

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::AddCanvasComponentTool.new
      tool.call(content: '<p>Widget</p>')
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="append"'
    assert_includes html, "canvas-components-#{page.id}"
  ensure
    ENV.delete('PAGE_ID')
  end

  # --- RemoveCanvasComponentTool ---

  def test_remove_canvas_component_tool_broadcasts_remove
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    component = page.canvas_components.create!(
      component_type: 'card', content: '<p>hi</p>',
      x: 0, y: 0, width: 320, z_index: 0
    )

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::RemoveCanvasComponentTool.new
      tool.call(component_id: component.id)
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="remove"'
    assert_includes html, "canvas-component-#{component.id}"
  end

  # --- UpdateCanvasComponentTool ---

  def test_update_canvas_component_tool_broadcasts_replace
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    component = page.canvas_components.create!(
      component_type: 'card', content: '<p>old</p>',
      x: 0, y: 0, width: 320, z_index: 0
    )

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::UpdateCanvasComponentTool.new
      tool.call(component_id: component.id, content: '<p>new</p>')
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="replace"'
    assert_includes html, "canvas-component-#{component.id}"
  end

  # --- UpdateCanvasTool ---

  def test_update_canvas_tool_replace_mode_broadcasts_update
    page = Fang::Page.create!(title: 'Canvas', content: '', status: 'published', published_at: Time.current)
    conversation = Fang::Conversation.create!(title: 'Test', source: 'web', page: page)

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::UpdateCanvasTool.new
      tool.call(html: '<h1>Dashboard</h1>', conversation_id: conversation.id, mode: 'replace')
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="update"'
    assert_includes html, "canvas-page-#{page.id}"
    assert_includes html, '<h1>Dashboard</h1>'
  end

  def test_update_canvas_tool_append_mode_broadcasts_append
    page = Fang::Page.create!(title: 'Canvas', content: '<p>existing</p>', status: 'published', published_at: Time.current)
    conversation = Fang::Conversation.create!(title: 'Test', source: 'web', page: page)

    captured = capture_broadcasts("canvas:#{page.id}") do
      tool = Fang::Tools::UpdateCanvasTool.new
      tool.call(html: '<p>more</p>', conversation_id: conversation.id, mode: 'append')
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="append"'
    assert_includes html, "canvas-page-#{page.id}"
    assert_includes html, '<p>more</p>'
  end

  # --- DefineWidgetTool ---

  def test_define_widget_tool_broadcasts_script_when_js_given
    # The tool writes ruby to <root>/widgets/ and js to <root>/web/public/js/widgets/
    # (resolved via File.expand_path from fang/tools/__dir__)
    tool_dir = File.dirname(Fang::Tools::DefineWidgetTool.instance_method(:call).source_location.first)
    @_ruby_dir = File.expand_path('../../widgets', tool_dir)
    @_js_dir   = File.expand_path('../../web/public/js/widgets', tool_dir)
    FileUtils.mkdir_p(@_ruby_dir)
    FileUtils.mkdir_p(@_js_dir)

    ruby_code = <<~RUBY
      module Fang
        module Widgets
          class TestBroadcastWidget < BaseWidget
            widget_type 'test_broadcast'
            def render_content
              '<p>test</p>'
            end
          end
        end
      end
    RUBY

    js_code = 'registerWidget("test_broadcast", {})'

    captured = capture_broadcasts('notifications') do
      tool = Fang::Tools::DefineWidgetTool.new
      tool.call(widget_type: 'test_broadcast', ruby_code: ruby_code, js_code: js_code)
    end

    assert_equal 1, captured.size
    html = captured.first
    assert_includes html, 'action="append"'
    assert_includes html, 'target="head"'
    assert_includes html, 'test_broadcast.js'
  ensure
    File.delete(File.join(@_ruby_dir, 'test_broadcast_widget.rb')) rescue nil
    File.delete(File.join(@_js_dir, 'test_broadcast.js')) rescue nil
    Dir.rmdir(@_ruby_dir) if @_ruby_dir && Dir.exist?(@_ruby_dir) && Dir.empty?(@_ruby_dir)
  end

  def test_define_widget_tool_no_broadcast_without_js
    tool_dir = File.dirname(Fang::Tools::DefineWidgetTool.instance_method(:call).source_location.first)
    @_ruby_dir = File.expand_path('../../widgets', tool_dir)
    FileUtils.mkdir_p(@_ruby_dir)

    ruby_code = <<~RUBY
      module Fang
        module Widgets
          class TestNojsWidget < BaseWidget
            widget_type 'test_nojs'
            def render_content
              '<p>no js</p>'
            end
          end
        end
      end
    RUBY

    captured = capture_broadcasts('notifications') do
      tool = Fang::Tools::DefineWidgetTool.new
      tool.call(widget_type: 'test_nojs', ruby_code: ruby_code)
    end

    assert_empty captured
  ensure
    File.delete(File.join(@_ruby_dir, 'test_nojs_widget.rb')) rescue nil
    Dir.rmdir(@_ruby_dir) if @_ruby_dir && Dir.exist?(@_ruby_dir) && Dir.empty?(@_ruby_dir)
  end
end
