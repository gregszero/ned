# frozen_string_literal: true

require 'open3'
require 'base64'
require 'securerandom'

module Fang
  module ComputerUse
    class DisplayServer
      attr_reader :display, :width, :height, :session_id

      def initialize(display: ":99", width: 1024, height: 768)
        @display = display
        @width = width
        @height = height
        @session_id = SecureRandom.hex(8)
        @xvfb_pid = nil
      end

      def start
        # Launch Xvfb
        @xvfb_pid = Process.spawn(
          "Xvfb", display, "-screen", "0", "#{width}x#{height}x24", "-ac",
          [:out, :err] => "/dev/null"
        )
        Process.detach(@xvfb_pid)

        # Wait for display to be ready
        wait_for_display

        # Start window manager
        spawn_in_display("openbox")
        sleep 0.5

        # Start Firefox
        spawn_in_display("firefox", "--no-remote")
        sleep 2

        Fang.logger.info "DisplayServer started on #{display} (#{width}x#{height}), session #{session_id}"
        true
      rescue => e
        stop
        raise e
      end

      def stop
        if @xvfb_pid
          begin
            Process.kill("-TERM", @xvfb_pid)
          rescue Errno::ESRCH
            # already dead
          end
          @xvfb_pid = nil
        end
        cleanup_screenshot
        Fang.logger.info "DisplayServer stopped for session #{session_id}"
      end

      def running?
        return false unless @xvfb_pid
        Process.kill(0, @xvfb_pid)
        true
      rescue Errno::ESRCH
        false
      end

      def screenshot
        path = screenshot_path
        run_command("scrot", "-o", path)
        data = Base64.strict_encode64(File.binread(path))
        data
      end

      def exec_action(action, params = {})
        case action.to_s
        when "left_click"
          coords = params["coordinate"] || params[:coordinate]
          run_command("xdotool", "mousemove", "--sync", coords[0].to_s, coords[1].to_s, "click", "1")
        when "right_click"
          coords = params["coordinate"] || params[:coordinate]
          run_command("xdotool", "mousemove", "--sync", coords[0].to_s, coords[1].to_s, "click", "3")
        when "double_click"
          coords = params["coordinate"] || params[:coordinate]
          run_command("xdotool", "mousemove", "--sync", coords[0].to_s, coords[1].to_s, "click", "--repeat", "2", "1")
        when "type"
          text = params["text"] || params[:text]
          run_command("xdotool", "type", "--delay", "50", text.to_s)
        when "key"
          key = params["key"] || params[:key]
          run_command("xdotool", "key", key.to_s)
        when "scroll"
          coords = params["coordinate"] || params[:coordinate]
          direction = params["direction"] || params[:direction]
          amount = (params["amount"] || params[:amount] || 3).to_i
          button = direction == "up" ? "4" : "5"
          run_command("xdotool", "mousemove", "--sync", coords[0].to_s, coords[1].to_s)
          amount.times { run_command("xdotool", "click", button) }
        when "mouse_move"
          coords = params["coordinate"] || params[:coordinate]
          run_command("xdotool", "mousemove", "--sync", coords[0].to_s, coords[1].to_s)
        when "screenshot"
          # just capture, handled below
        when "cursor_position"
          output, = run_command("xdotool", "getmouselocation")
          return output.strip
        else
          Fang.logger.warn "Unknown CUA action: #{action}"
        end

        # Auto-capture screenshot after actions (except cursor_position)
        unless action.to_s == "cursor_position"
          sleep 1
          screenshot
        end
      end

      private

      def screenshot_path
        "/tmp/cua-screenshot-#{session_id}.png"
      end

      def cleanup_screenshot
        path = screenshot_path
        File.delete(path) if File.exist?(path)
      end

      def wait_for_display(timeout: 5)
        deadline = Time.now + timeout
        loop do
          _, status = Open3.capture2e({ "DISPLAY" => display }, "xset", "q")
          return true if status.success?
          raise "Xvfb failed to start on #{display}" if Time.now > deadline
          sleep 0.2
        end
      end

      def spawn_in_display(*cmd)
        pid = Process.spawn({ "DISPLAY" => display }, *cmd, [:out, :err] => "/dev/null")
        Process.detach(pid)
        pid
      end

      def run_command(*cmd)
        stdout, stderr, status = Open3.capture3({ "DISPLAY" => display }, *cmd)
        unless status.success?
          Fang.logger.warn "CUA command failed: #{cmd.join(' ')} — #{stderr}"
        end
        [stdout, stderr, status]
      end
    end
  end
end
