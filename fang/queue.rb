# frozen_string_literal: true

require 'active_job'
require 'delayed_job'
require 'delayed_job_active_record'

module Fang
  class Queue
    class << self
      def configure!
        ActiveJob::Base.queue_adapter = :delayed_job

        Delayed::Worker.max_attempts = 3
        Delayed::Worker.destroy_failed_jobs = false
        Delayed::Worker.sleep_delay = 3
        Delayed::Worker.logger = Fang.logger

        Fang.logger.info "Queue adapter: #{ActiveJob::Base.queue_adapter.class.name}"
      end

      def start!
        @worker_thread = Thread.new do
          worker = Delayed::Worker.new
          worker.start
        end
        Fang.logger.info "Delayed job worker started"
      end

      def stop!
        if @worker_thread
          Delayed::Worker.lifecycle.execute(:stop)
          @worker_thread.kill
          @worker_thread = nil
          Fang.logger.info "Delayed job worker stopped"
        end
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

# Auto-configure
Fang::Queue.configure!
