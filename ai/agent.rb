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

        cmd = [
          'claude',
          '-p', prompt,
          '--output-format', 'json',
          '--session-id', uuid,
          '--max-turns', '25'
        ]

        env = build_env(conversation)

        Ai.logger.info "Spawning claude subprocess (session: #{session_id})"

        stdout, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          Ai.logger.error "Claude exited with code #{status.exitstatus}: #{stderr}"
          return { 'type' => 'error', 'message' => "Agent exited with code #{status.exitstatus}: #{stderr}" }
        end

        parse_response(stdout)
      rescue Errno::ENOENT
        Ai.logger.error "claude command not found. Ensure Claude Code CLI is installed and in PATH."
        { 'type' => 'error', 'message' => 'claude command not found' }
      rescue => e
        Ai.logger.error "Agent execution failed: #{e.message}"
        { 'type' => 'error', 'message' => e.message }
      end

      private

      def build_env(conversation)
        env = {}

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

      # Convert any value to a deterministic UUID v5 (SHA-1 based)
      def to_uuid(value)
        hash = Digest::SHA1.hexdigest("ai.rb:#{value}")
        # Format as UUID v5: xxxxxxxx-xxxx-5xxx-Nxxx-xxxxxxxxxxxx
        [hash[0..7], hash[8..11], "5#{hash[13..15]}", "#{(hash[16].to_i(16) & 0x3 | 0x8).to_s(16)}#{hash[17..19]}", hash[20..31]].join('-')
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
