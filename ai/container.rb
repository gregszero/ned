# frozen_string_literal: true

require 'docker'
require 'securerandom'
require 'fileutils'

module Ai
  class Container
    class << self
      # Spawn a new container for a conversation
      def spawn(conversation_id)
        session = create_session(conversation_id)
        prepare_workspace(session)

        container = Docker::Container.create(
          'Image' => 'ai-rb-agent',
          'Cmd' => build_command(session),
          'Env' => build_env(session),
          'HostConfig' => {
            'Binds' => [
              "#{Ai.root}/workspace:/workspace:rw",
              "#{session.session_path}:/session:rw"
            ],
            'ExtraHosts' => ['host.docker.internal:host-gateway']
          },
          'WorkingDir' => '/workspace'
        )

        container.start
        session.update!(
          container_id: container.id,
          status: 'running',
          started_at: Time.now
        )

        Ai.logger.info "Container #{container.id[0..11]} started for conversation #{conversation_id}"
        session
      rescue Docker::Error::NotFoundError
        Ai.logger.error "Docker image 'ai-rb-agent' not found. Run: docker build -f container/Dockerfile -t ai-rb-agent ."
        raise
      rescue => e
        session&.update!(status: 'error')
        Ai.logger.error "Failed to spawn container: #{e.message}"
        raise
      end

      # Send a message to a running container via stdin
      def send_message(session, content)
        container = Docker::Container.get(session.container_id)

        message_json = {
          type: 'message',
          content: content,
          context: {
            conversation_id: session.conversation_id,
            mcp_url: "http://host.docker.internal:9292/mcp"
          }
        }.to_json

        # Write to container stdin
        container.attach(stdin: true) do |stream|
          stream.write(message_json + "\n")
        end

        Ai.logger.debug "Sent message to container #{session.container_id[0..11]}"
      rescue => e
        Ai.logger.error "Failed to send message to container: #{e.message}"
        raise
      end

      # Read response from container stdout
      def read_response(session, &block)
        container = Docker::Container.get(session.container_id)

        container.attach(stdout: true, stream: true) do |stream, chunk|
          chunk.each_line do |line|
            next unless line.strip.start_with?('{')

            begin
              data = JSON.parse(line)
              yield data if block_given?
            rescue JSON::ParserError => e
              Ai.logger.warn "Failed to parse container output: #{line}"
            end
          end
        end
      rescue => e
        Ai.logger.error "Failed to read from container: #{e.message}"
        raise
      end

      # Stop a running container
      def stop(session)
        container = Docker::Container.get(session.container_id)
        container.stop(t: 10) # 10 second timeout
        session.update!(
          status: 'stopped',
          stopped_at: Time.now
        )

        Ai.logger.info "Container #{session.container_id[0..11]} stopped"
      rescue Docker::Error::NotFoundError
        Ai.logger.warn "Container #{session.container_id} not found (may have already stopped)"
        session.update!(status: 'stopped', stopped_at: Time.now)
      rescue => e
        Ai.logger.error "Failed to stop container: #{e.message}"
        raise
      end

      # Cleanup old/stopped containers
      def cleanup_old_sessions
        # Find sessions older than 30 minutes and stopped
        old_sessions = Session.where(status: 'stopped')
                             .where('stopped_at < ?', 30.minutes.ago)

        old_sessions.each do |session|
          begin
            container = Docker::Container.get(session.container_id)
            container.delete(force: true)
            Ai.logger.info "Cleaned up container #{session.container_id[0..11]}"
          rescue Docker::Error::NotFoundError
            # Already deleted
          end

          # Remove session directory
          FileUtils.rm_rf(session.session_path) if Dir.exist?(session.session_path)
        end
      end

      private

      def create_session(conversation_id)
        Session.create!(
          conversation_id: conversation_id,
          status: 'starting',
          session_path: "#{Ai.root}/storage/sessions/#{SecureRandom.uuid}"
        )
      end

      def prepare_workspace(session)
        FileUtils.mkdir_p(session.session_path)

        # Copy CLAUDE.md template if it exists
        claude_template = "#{Ai.root}/workspace/CLAUDE.md"
        if File.exist?(claude_template)
          FileUtils.cp(claude_template, "#{session.session_path}/CLAUDE.md")
        else
          # Create basic CLAUDE.md
          File.write("#{session.session_path}/CLAUDE.md", <<~CLAUDE)
            # AI Assistant Memory

            ## Context
            This is conversation ##{session.conversation_id}

            ## Instructions
            You are an AI assistant with access to Ruby skills and MCP tools.
          CLAUDE
        end
      end

      def build_command(session)
        [
          'claude', 'code',
          '--session', '/session'
        ]
      end

      def build_env(session)
        env = [
          "CONVERSATION_ID=#{session.conversation_id}",
          "MCP_URL=http://host.docker.internal:9292/mcp",
          "SESSION_PATH=/session"
        ]

        # Add authentication (prefer OAuth token, fallback to API key)
        if ENV['CLAUDE_CODE_OAUTH_TOKEN']
          env << "CLAUDE_CODE_OAUTH_TOKEN=#{ENV['CLAUDE_CODE_OAUTH_TOKEN']}"
        elsif ENV['ANTHROPIC_API_KEY']
          env << "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}"
        else
          Ai.logger.warn "No CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY found"
        end

        env
      end
    end
  end
end
