# frozen_string_literal: true

require 'open3'
require 'json'

module Fang
  module PythonRunner
    TIMEOUT = 30 # seconds
    BRIDGE_PATH = File.expand_path('python/bridge.py', __dir__)
    SKILL_RUNNER_PATH = File.expand_path('python/skill_runner.py', __dir__)

    class << self
      def venv_path
        File.join(Fang.root, 'workspace', 'python', 'venv')
      end

      def python_bin
        File.join(venv_path, 'bin', 'python')
      end

      def pip_bin
        File.join(venv_path, 'bin', 'pip')
      end

      def venv_exists?
        File.executable?(python_bin)
      end

      def ensure_venv!
        return if venv_exists?

        Fang.logger.info "Creating Python virtualenv at #{venv_path}"
        dir = File.dirname(venv_path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

        stdout, stderr, status = Open3.capture3('python3', '-m', 'venv', venv_path)
        unless status.success?
          raise "Failed to create virtualenv: #{stderr}"
        end

        Fang.logger.info "Python virtualenv created successfully"
        true
      end

      def run_code(code, context: {})
        ensure_venv!

        input = JSON.generate({ code: code, context: context })
        stdout, stderr, status = run_python(BRIDGE_PATH, stdin_data: input)

        parse_result(stdout, stderr, status)
      end

      def run_skill(skill_path, params: {}, context: {})
        ensure_venv!

        full_path = if File.absolute_path?(skill_path)
                      skill_path
                    else
                      File.join(Fang.root, skill_path)
                    end

        unless File.exist?(full_path)
          return { success: false, error: "Skill file not found: #{full_path}" }
        end

        input = JSON.generate({ params: params, context: context })
        stdout, stderr, status = run_python(SKILL_RUNNER_PATH, args: [full_path], stdin_data: input)

        parse_result(stdout, stderr, status)
      end

      def pip_install(*packages)
        ensure_venv!

        packages = packages.flatten
        return { success: false, error: 'No packages specified' } if packages.empty?

        Fang.logger.info "Installing Python packages: #{packages.join(', ')}"
        stdout, stderr, status = Open3.capture3(pip_bin, 'install', *packages)

        if status.success?
          { success: true, output: stdout.strip }
        else
          { success: false, error: stderr.strip.empty? ? stdout.strip : stderr.strip }
        end
      end

      def pip_list
        ensure_venv!

        stdout, stderr, status = Open3.capture3(pip_bin, 'list', '--format=json')
        if status.success?
          packages = JSON.parse(stdout)
          { success: true, packages: packages }
        else
          { success: false, error: stderr.strip }
        end
      end

      def process_actions(actions)
        return unless actions.is_a?(Array)

        actions.each do |action|
          case action['type']
          when 'send_message'
            conv_id = action['conversation_id'] || ENV['CONVERSATION_ID']
            next unless conv_id
            conversation = Fang::Conversation.find(conv_id)
            conversation.add_message(role: 'system', content: action['content'])
          when 'create_notification'
            Fang::Notification.create!(
              title: action['title'],
              body: action['body'],
              kind: action['kind'] || 'info'
            ).broadcast!
          else
            Fang.logger.warn "Unknown Python action type: #{action['type']}"
          end
        rescue => e
          Fang.logger.error "Failed to process Python action #{action}: #{e.message}"
        end
      end

      private

      def run_python(script, args: [], stdin_data: nil)
        cmd = [python_bin, script, *args]

        Open3.capture3(*cmd, stdin_data: stdin_data, timeout: TIMEOUT)
      rescue Errno::ETIMEDOUT
        raise "Python execution timed out after #{TIMEOUT} seconds"
      end

      def parse_result(stdout, stderr, status)
        unless status.success?
          error = stderr.to_s.strip
          error = stdout.to_s.strip if error.empty?
          error = "Python process exited with code #{status.exitstatus}" if error.empty?
          return { success: false, error: error }
        end

        # Find the last line of JSON output (bridge outputs result as last line)
        lines = stdout.to_s.strip.split("\n")
        json_line = lines.reverse.find { |l| l.start_with?('{') }

        unless json_line
          return { success: true, result: stdout.to_s.strip, output: stdout.to_s.strip }
        end

        result = JSON.parse(json_line)

        # Process any actions from Python
        process_actions(result['actions']) if result['actions']

        # Convert keys to symbols for consistency
        {
          success: result['success'],
          result: result['result'],
          output: result['output'],
          error: result['error']
        }.compact
      rescue JSON::ParserError
        { success: true, result: stdout.to_s.strip, output: stdout.to_s.strip }
      end
    end
  end
end
