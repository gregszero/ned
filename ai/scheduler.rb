# frozen_string_literal: true

require 'rufus-scheduler'

module Ai
  class Scheduler
    class << self
      attr_reader :instance

      def start!
        return if @instance

        @instance = Rufus::Scheduler.new

        # Poll for due scheduled tasks every 60 seconds
        @instance.every '60s', first: :now do
          run_due_tasks
        end

        Ai.logger.info "Scheduler started (polling every 60s)"
      end

      def stop!
        return unless @instance

        @instance.shutdown(:wait)
        @instance = nil
        Ai.logger.info "Scheduler stopped"
      end

      def running?
        @instance&.up?
      end

      private

      def run_due_tasks
        tasks = ScheduledTask.due
        return if tasks.empty?

        Ai.logger.info "Found #{tasks.count} due task(s)"

        tasks.each do |task|
          Jobs::ScheduledTaskRunnerJob.perform_later(task.id)
        end
      rescue => e
        Ai.logger.error "Scheduler error: #{e.message}"
      end
    end
  end
end
