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
        resuming = session.persisted? && session.stopped?

        session.start!

        cmd = [
          'claude',
          '-p', prompt,
          '--output-format', 'json',
          '--max-turns', '25'
        ]

        # Resume existing session or start new one
        if resuming
          cmd += ['--resume', uuid]
        else
          cmd += ['--session-id', uuid]
        end

        env = build_env(conversation)

        Ai.logger.info "#{resuming ? 'Resuming' : 'Starting'} claude subprocess (session: #{uuid})"

        stdout, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          session.error!
          Ai.logger.error "Claude exited with code #{status.exitstatus}: #{stderr}"
          return { 'type' => 'error', 'message' => "Agent exited with code #{status.exitstatus}: #{stderr}" }
        end

        session.stop!
        parse_response(stdout)
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
        content = data['result'] || data['content'] || output
        { 'type' => 'content', 'content' => content.to_s, 'done' => true }
      rescue JSON::ParserError
        { 'type' => 'content', 'content' => output.strip, 'done' => true }
      end
    end
  end
end
