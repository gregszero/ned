# frozen_string_literal: true

require_relative '../../web/turbo_broadcast'
require_relative '../../web/view_helpers'

module Fang
  module Jobs
    class ComputerUseExecutorJob < ApplicationJob
      include Web::ViewHelpers

      queue_as :agent_execution

      # Don't retry CUA jobs — they manage external processes
      retry_on StandardError, attempts: 1

      def perform(message_id, task:)
        message = Message.find(message_id)
        conversation = message.conversation
        channel = conversation.broadcast_channel
        page = conversation.page

        progress_id = "cua-progress-#{message_id}"
        broadcast_progress_container(conversation, progress_id)
        broadcast_step(channel, progress_id, "Starting virtual display...", "tool")

        # Create canvas widget
        component = create_canvas_component(page)
        broadcast_canvas_widget(channel, component)

        # Start display server
        display = ComputerUse::DisplayServer.new
        display.start
        broadcast_step(channel, progress_id, "Display ready, launching browser...", "tool")

        # Run the CUA agent loop
        agent = ComputerUse::Agent.new(display_server: display)
        accumulated_text = ""

        agent.execute(task: task) do |event|
          case event[:type]
          when :screenshot
            update_widget_screenshot(channel, component, event[:base64])
          when :action
            label = format_action(event[:action], event[:params])
            broadcast_step(channel, progress_id, label, "tool")
            update_widget_metadata(component, status: "running", last_action: label)
          when :text
            accumulated_text = event[:content]
            broadcast_streaming_text(channel, progress_id, accumulated_text)
          end
        end

        # Done
        display.stop
        update_widget_metadata(component, status: "stopped", last_action: "Complete")

        result_text = accumulated_text.strip
        result_text = "Computer use task completed." if result_text.empty?
        response_message = conversation.add_message(role: 'assistant', content: result_text)
        broadcast_final(conversation, progress_id, response_message)

      rescue => e
        Fang.logger.error "CUA execution failed: #{e.message}"
        Fang.logger.error e.backtrace.first(10).join("\n")
        display&.stop
        update_widget_metadata(component, status: "error", last_action: e.message) if component
        error_msg = conversation&.add_message(role: 'system', content: "Computer use error: #{e.message}")
        broadcast_final(conversation, progress_id, error_msg) if conversation && error_msg
      end

      private

      def create_canvas_component(page)
        CanvasComponent.create!(
          page: page,
          component_type: "computer_use",
          x: 20, y: 20,
          width: 1064, height: 820,
          z_index: 10,
          metadata: { "status" => "running", "last_action" => "Starting..." }
        )
      end

      def broadcast_canvas_widget(channel, component)
        html = turbo_stream('append', "canvas-#{component.page_id}") do
          component.render_html
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def update_widget_screenshot(channel, component, base64_data)
        html = turbo_stream('update', "cua-screen-#{component.id}") do
          %(<img id="cua-screen-#{component.id}" class="cua-screen" src="data:image/png;base64,#{base64_data}" alt="Computer screen" />)
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def update_widget_metadata(component, **updates)
        meta = (component.metadata || {}).merge(updates.transform_keys(&:to_s))
        component.update!(metadata: meta)
      end

      def format_action(action, params)
        case action.to_s
        when "left_click"
          coords = params["coordinate"] || params[:coordinate]
          "Click at (#{coords&.join(', ')})"
        when "right_click"
          coords = params["coordinate"] || params[:coordinate]
          "Right-click at (#{coords&.join(', ')})"
        when "double_click"
          coords = params["coordinate"] || params[:coordinate]
          "Double-click at (#{coords&.join(', ')})"
        when "type"
          text = params["text"] || params[:text]
          "Typing '#{text.to_s[0..40]}'"
        when "key"
          key = params["key"] || params[:key]
          "Key press: #{key}"
        when "scroll"
          direction = params["direction"] || params[:direction]
          "Scroll #{direction}"
        when "mouse_move"
          coords = params["coordinate"] || params[:coordinate]
          "Mouse move to (#{coords&.join(', ')})"
        when "screenshot"
          "Taking screenshot"
        when "cursor_position"
          "Getting cursor position"
        else
          action.to_s
        end
      end

      def broadcast_progress_container(conversation, progress_id)
        html = turbo_stream('append', "messages-#{conversation.id}") do
          <<~HTML
            <div class="chat-msg ai" id="#{progress_id}">
              <div class="msg-meta flex items-center gap-2 mb-1">
                <span>AI</span>
              </div>
              <div class="agent-steps" id="#{progress_id}-steps"></div>
              <div class="prose-bubble" id="#{progress_id}-response"></div>
            </div>
          HTML
        end
        Web::TurboBroadcast.broadcast(conversation.broadcast_channel, html)
      end

      def broadcast_step(channel, progress_id, label, kind)
        html = turbo_stream('append', "#{progress_id}-steps") do
          <<~HTML
            <div class="agent-step" data-kind="#{kind}">
              <span class="agent-step-icon"></span>
              <span>#{ERB::Util.html_escape(label)}</span>
            </div>
          HTML
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def broadcast_streaming_text(channel, progress_id, text)
        html = turbo_stream('update', "#{progress_id}-response") do
          %(<div class="prose">#{render_markdown(text)}</div>)
        end
        Web::TurboBroadcast.broadcast(channel, html)
      end

      def broadcast_final(conversation, progress_id, message)
        html = turbo_stream('remove', progress_id) {} +
               turbo_stream('append', "messages-#{conversation.id}") { render_message_html(message) }
        Web::TurboBroadcast.broadcast(conversation.broadcast_channel, html)
      end
    end
  end
end
