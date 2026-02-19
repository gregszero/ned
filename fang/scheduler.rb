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

        # Refresh widgets every 5 minutes
        @instance.every '5m' do
          refresh_widgets
        end

        # Poll for due heartbeats every 30 seconds
        @instance.every '30s', first: :now do
          run_due_heartbeats
        end

        Ai.logger.info "Scheduler started (polling every 60s, heartbeats every 30s, widget refresh every 5m)"
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

      def run_due_heartbeats
        heartbeats = Heartbeat.due.select(&:due_now?)
        return if heartbeats.empty?

        Ai.logger.info "Found #{heartbeats.count} due heartbeat(s)"

        heartbeats.each do |hb|
          Jobs::HeartbeatRunnerJob.perform_later(hb.id)
        end
      rescue => e
        Ai.logger.error "Heartbeat scheduler error: #{e.message}"
      end

      def refresh_widgets
        Jobs::WidgetRefreshJob.perform_later
      rescue => e
        Ai.logger.error "Widget refresh scheduling error: #{e.message}"
      end
    end
  end
end
