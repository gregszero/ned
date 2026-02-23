# frozen_string_literal: true

require 'rufus-scheduler'

module Fang
  class Scheduler
    class << self
      attr_reader :instance

      def start!
        return if @instance

        @instance = Rufus::Scheduler.new

        # Poll for due scheduled tasks every 60 seconds
        @instance.every '60s', first: :now, tag: 'Scheduled Tasks Poll' do
          run_due_tasks
        end

        # Refresh widgets every 5 minutes
        @instance.every '5m', tag: 'Widget Refresh' do
          refresh_widgets
        end

        # Poll for due heartbeats every 30 seconds
        @instance.every '30s', first: :now, tag: 'Heartbeat Poll' do
          run_due_heartbeats
        end

        Fang.logger.info "Scheduler started (polling every 60s, heartbeats every 30s, widget refresh every 5m)"
      end

      def stop!
        return unless @instance

        @instance.shutdown(:wait)
        @instance = nil
        Fang.logger.info "Scheduler stopped"
      end

      def running?
        @instance&.up?
      end

      def jobs
        return [] unless @instance

        @instance.jobs.map do |job|
          {
            name: job.tags.first || job.id,
            interval: "every #{job.original}",
            last_fired_at: job.last_time,
            next_fire_at: job.next_time&.to_t,
            status: job.paused? ? 'paused' : 'running'
          }
        end
      end

      private

      def run_due_tasks
        tasks = ScheduledTask.due
        return if tasks.empty?

        Fang.logger.info "Found #{tasks.count} due task(s)"

        tasks.each do |task|
          Jobs::ScheduledTaskRunnerJob.perform_later(task.id)
        end
      rescue => e
        Fang.logger.error "Scheduler error: #{e.message}"
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end

      def run_due_heartbeats
        heartbeats = Heartbeat.due.select(&:due_now?)
        return if heartbeats.empty?

        Fang.logger.info "Found #{heartbeats.count} due heartbeat(s)"

        heartbeats.each do |hb|
          Jobs::HeartbeatRunnerJob.perform_later(hb.id)
        end
      rescue => e
        Fang.logger.error "Heartbeat scheduler error: #{e.message}"
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end

      def refresh_widgets
        Jobs::WidgetRefreshJob.perform_later
      rescue => e
        Fang.logger.error "Widget refresh scheduling error: #{e.message}"
      ensure
        ActiveRecord::Base.connection_pool.release_connection
      end
    end
  end
end
