# frozen_string_literal: true

module Fang
  module Tools
    class ScheduleTaskTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'schedule_task'
      description 'Schedule a task to run at a specific time in the future'

      arguments do
        required(:title).filled(:string).description('Task title')
        required(:scheduled_for).filled(:string).description('ISO8601 timestamp or relative time (e.g., "2 minutes", "1 hour", "tomorrow")')
        optional(:description).filled(:string).description('Detailed task description')
        optional(:skill_name).filled(:string).description('Name of skill to execute')
        optional(:cron).filled(:string).description('Cron expression for recurring tasks (e.g., "*/5 * * * *" for every 5 minutes)')
      end

      def call(title:, scheduled_for:, description: nil, skill_name: nil, cron: nil)
        scheduled_time = parse_time(scheduled_for)

        unless scheduled_time
          return {
            success: false,
            error: "Invalid time format: #{scheduled_for}"
          }
        end

        recurring = false
        if cron
          parsed_cron = Fugit::Cron.parse(cron)
          unless parsed_cron
            return { success: false, error: "Invalid cron expression: #{cron}" }
          end
          recurring = true
        end

        task = ScheduledTask.create!(
          title: title,
          description: description,
          scheduled_for: scheduled_time,
          skill_name: skill_name,
          cron_expression: cron,
          recurring: recurring
        )

        Fang.logger.info "Scheduled task ##{task.id}: #{title} for #{scheduled_time}"

        {
          success: true,
          task_id: task.id,
          title: task.title,
          scheduled_for: task.scheduled_for.iso8601,
          recurring: task.recurring?,
          cron_expression: task.cron_expression
        }.compact
      rescue => e
        Fang.logger.error "Failed to schedule task: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def parse_time(time_string)
        # Try ISO8601 first
        begin
          return Time.parse(time_string)
        rescue ArgumentError
          # Continue to relative time parsing
        end

        case time_string.downcase
        when /^(\d+)\s*(second|seconds|sec|secs)$/
          $1.to_i.seconds.from_now
        when /^(\d+)\s*(minute|minutes|min|mins)$/
          $1.to_i.minutes.from_now
        when /^(\d+)\s*(hour|hours|hr|hrs)$/
          $1.to_i.hours.from_now
        when /^(\d+)\s*(day|days)$/
          $1.to_i.days.from_now
        when /^(\d+)\s*(week|weeks)$/
          $1.to_i.weeks.from_now
        when 'tomorrow'
          1.day.from_now
        when 'next week'
          1.week.from_now
        end
      end
    end
  end
end
