# frozen_string_literal: true

module Ai
  class Queue
    class << self
      def configure!
        # For now, use inline adapter (synchronous execution)
        # TODO: Switch to Solid Queue when Rails integration is set up
        Ai.logger.info "Queue adapter: #{ActiveJob::Base.queue_adapter.class.name}"
      end

      def enqueue(job_class, *args, **kwargs)
        job_class.perform_later(*args, **kwargs)
      end

      def enqueue_at(job_class, time, *args, **kwargs)
        job_class.set(wait_until: time).perform_later(*args, **kwargs)
      end

      # Schedule recurring tasks
      def schedule_recurring_tasks
        # Container cleanup every hour
        # Will be implemented when async queue is set up
        Ai.logger.info "Recurring tasks scheduling not yet implemented"
      end
    end
  end
end

# Configure ActiveJob to use inline adapter for now (synchronous)
# This executes jobs immediately in the same process
# TODO: Switch to async adapter (Solid Queue, Sidekiq, etc.) for production
ActiveJob::Base.queue_adapter = :inline

# Auto-configure
Ai::Queue.configure!
