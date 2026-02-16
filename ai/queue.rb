# frozen_string_literal: true

require 'active_job'

module Ai
  class Queue
    class << self
      def configure!
        Ai.logger.info "Queue adapter: #{ActiveJob::Base.queue_adapter.class.name}"
      end

      def enqueue(job_class, *args, **kwargs)
        job_class.perform_later(*args, **kwargs)
      end

      def enqueue_at(job_class, time, *args, **kwargs)
        job_class.set(wait_until: time).perform_later(*args, **kwargs)
      end
    end
  end
end

# Use async adapter (in-memory, no Rails dependency)
ActiveJob::Base.queue_adapter = :async

# Auto-configure
Ai::Queue.configure!
