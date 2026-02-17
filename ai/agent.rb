# frozen_string_literal: true

require 'open3'
require 'json'
require 'digest'

module Ai
  module Agent
    class << self
      # Execute a prompt via claude subprocess and return parsed response
      def execute(prompt:, session_id:, conversation: nil)
        uuid = to_uuid(session_id)
        session = find_or_create_session(conversation, uuid)
        resumable = session.stopped?

        session.start!

        result = run_claude(prompt: prompt, uuid: uuid, resuming: resumable, env: build_env(conversation))

        # If resume failed, retry as a new session
        if result[:failed] && resumable
          Ai.logger.warn "Resume failed, starting fresh session"
          result = run_claude(prompt: prompt, uuid: uuid, resuming: false, env: build_env(conversation))
        end

        # If session ID is "already in use", retry with --resume
        if result[:failed] && result[:error]&.include?('already in use')
          Ai.logger.warn "Session in use, retrying with --resume"
          result = run_claude(prompt: prompt, uuid: uuid, resuming: true, env: build_env(conversation))
        end

        if result[:failed]
          session.error!
          return { 'type' => 'error', 'message' => result[:error] }
        end

        session.stop!
        parse_response(result[:stdout])
      rescue Errno::ENOENT
        session&.error!
        Ai.logger.error "claude command not found. Ensure Claude Code CLI is installed and in PATH."
        { 'type' => 'error', 'message' => 'claude command not found' }
      rescue => e
        session&.error!
        Ai.logger.error "Agent execution failed: #{e.message}"
        { 'type' => 'error', 'message' => e.message }
      end

      private

      def run_claude(prompt:, uuid:, resuming:, env:)
        cmd = [
          'claude',
          '-p', prompt,
          '--output-format', 'json',
          '--max-turns', '25',
          '--permission-mode', 'bypassPermissions'
        ]

        if resuming
          cmd += ['--resume', uuid]
        else
          cmd += ['--session-id', uuid]
        end

        Ai.logger.info "#{resuming ? 'Resuming' : 'Starting'} claude subprocess (session: #{uuid})"

        stdout, stderr, status = Open3.capture3(env, *cmd)

        if status.success?
          { failed: false, stdout: stdout }
        else
          detail = stderr.to_s.strip
          detail = stdout.to_s.strip if detail.empty?
          detail = "(no output)" if detail.empty?
          Ai.logger.error "Claude exited with code #{status.exitstatus}:\nstderr: #{stderr}\nstdout: #{stdout}"
          { failed: true, error: "Agent exited with code #{status.exitstatus}:\n#{detail}" }
        end
      end

      def find_or_create_session(conversation, uuid)
        return Session.create!(status: 'starting') unless conversation

        # Reuse existing session for this conversation or create one
        conversation.sessions.find_by(container_id: uuid) ||
          conversation.sessions.create!(container_id: uuid, status: 'starting')
      end

      # Convert any value to a deterministic UUID v5 (SHA-1 based)
      def to_uuid(value)
        hash = Digest::SHA1.hexdigest("ai.rb:#{value}")
        [hash[0..7], hash[8..11], "5#{hash[13..15]}", "#{(hash[16].to_i(16) & 0x3 | 0x8).to_s(16)}#{hash[17..19]}", hash[20..31]].join('-')
      end

      def build_env(conversation)
        # Start with current environment so claude can find PATH, HOME, etc.
        env = ENV.to_h.dup

        # Unset CLAUDECODE to avoid nested session detection
        env.delete('CLAUDECODE')

        if ENV['CLAUDE_CODE_OAUTH_TOKEN']
          env['CLAUDE_CODE_OAUTH_TOKEN'] = ENV['CLAUDE_CODE_OAUTH_TOKEN']
        elsif ENV['ANTHROPIC_API_KEY']
          env['ANTHROPIC_API_KEY'] = ENV['ANTHROPIC_API_KEY']
        else
          Ai.logger.warn "No CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY found"
        end

        env['CONVERSATION_ID'] = conversation.id.to_s if conversation
        env
      end

      def parse_response(output)
        return { 'type' => 'error', 'message' => 'Empty response from agent' } if output.strip.empty?

        data = JSON.parse(output)

        # result can be empty when claude spent all turns on tool use
        content = data['result'].to_s.strip
        content = data['content'].to_s.strip if content.empty?
        content = summarize_tool_use(data) if content.empty?

        { 'type' => 'content', 'content' => content, 'done' => true }
      rescue JSON::ParserError
        { 'type' => 'content', 'content' => output.strip, 'done' => true }
      end

      def summarize_tool_use(data)
        parts = []
        parts << "Completed in #{data['num_turns']} turn(s)." if data['num_turns']
        parts << "Cost: $#{'%.4f' % data['total_cost_usd']}." if data['total_cost_usd']
        parts.empty? ? "Task completed (no text response)." : parts.join(' ')
      end
    end
  end
end
