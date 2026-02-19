# frozen_string_literal: true

require 'active_job'

module Fang
  module Jobs
    class ApplicationJob < ActiveJob::Base
      # Base class for all jobs

      # Automatically retry jobs on errors
      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      # Don't retry on specific errors
      discard_on ActiveJob::DeserializationError

      before_perform do |job|
        Fang.logger.info "Starting job: #{job.class.name} with args: #{job.arguments.inspect}"
      end

      after_perform do |job|
        Fang.logger.info "Completed job: #{job.class.name}"
      end

      around_perform do |job, block|
        start_time = Time.current
        block.call
        duration = Time.current - start_time
        Fang.logger.info "Job #{job.class.name} took #{duration.round(2)}s"
      end
    end
  end
end
