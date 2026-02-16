# frozen_string_literal: true

module Ai
  module Jobs
    class MemorySyncJob < ApplicationJob
      queue_as :default

      # Sync CLAUDE.md from filesystem to database
      def perform(session_id)
        session = Session.find(session_id)
        conversation = session.conversation

        Ai.logger.info "Syncing memory for session #{session_id}"

        # Read CLAUDE.md from session directory
        claude_md_path = File.join(session.session_path, 'CLAUDE.md')

        unless File.exist?(claude_md_path)
          Ai.logger.warn "CLAUDE.md not found at #{claude_md_path}"
          return
        end

        content = File.read(claude_md_path)

        # Store in conversation context
        conversation.update!(
          context: conversation.context.merge(
            claude_md: content,
            last_synced_at: Time.current.iso8601
          )
        )

        Ai.logger.info "Memory synced for conversation #{conversation.id}"

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Session not found: #{e.message}"
      rescue => e
        Ai.logger.error "Memory sync failed: #{e.message}"
        raise
      end
    end
  end
end
