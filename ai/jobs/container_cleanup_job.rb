# frozen_string_literal: true

module Ai
  module Jobs
    class ContainerCleanupJob < ApplicationJob
      queue_as :default

      # Cleanup old containers and sessions
      def perform
        Ai.logger.info "Running container cleanup..."

        cleaned_count = 0

        # Find sessions that should be cleaned up
        # - Stopped sessions older than 30 minutes
        # - Running sessions idle for more than 2 hours
        sessions_to_cleanup = Session.where(
          status: 'stopped'
        ).where(
          'stopped_at < ?', 30.minutes.ago
        )

        sessions_to_cleanup.each do |session|
          begin
            # Stop container if still running
            if session.container_id
              begin
                container = Docker::Container.get(session.container_id)
                container.delete(force: true)
                Ai.logger.info "Removed container #{session.container_id[0..11]}"
              rescue Docker::Error::NotFoundError
                # Container already removed
                Ai.logger.debug "Container #{session.container_id[0..11]} already removed"
              end
            end

            # Remove session directory
            if session.session_path && Dir.exist?(session.session_path)
              FileUtils.rm_rf(session.session_path)
              Ai.logger.info "Removed session directory: #{session.session_path}"
            end

            cleaned_count += 1
          rescue => e
            Ai.logger.error "Failed to cleanup session #{session.id}: #{e.message}"
          end
        end

        # Cleanup zombie containers (containers without session records)
        cleanup_zombie_containers

        Ai.logger.info "Container cleanup complete: #{cleaned_count} sessions cleaned"
      rescue => e
        Ai.logger.error "Container cleanup failed: #{e.message}"
        raise
      end

      private

      def cleanup_zombie_containers
        # Get all running containers with our image
        containers = Docker::Container.all(
          all: true,
          filters: { ancestor: ['ai-rb-agent'] }.to_json
        )

        containers.each do |container|
          container_id = container.id

          # Check if we have a session record for this container
          unless Session.exists?(container_id: container_id)
            Ai.logger.warn "Found zombie container #{container_id[0..11]}, removing..."
            begin
              container.delete(force: true)
            rescue => e
              Ai.logger.error "Failed to remove zombie container: #{e.message}"
            end
          end
        end
      rescue Docker::Error::ServerError => e
        Ai.logger.warn "Docker API error during zombie cleanup: #{e.message}"
      end
    end
  end
end
