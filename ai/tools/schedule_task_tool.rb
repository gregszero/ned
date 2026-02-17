# frozen_string_literal: true

module Ai
  module Tools
    class ScheduleTaskTool < FastMcp::Tool
      tool_name 'schedule_task'
      description 'Schedule a task to run at a specific time in the future'

      arguments do
        required(:title).filled(:string).description('Task title')
        required(:scheduled_for).filled(:string).description('ISO8601 timestamp or relative time (e.g., "2 minutes", "1 hour", "tomorrow")')
        optional(:description).filled(:string).description('Detailed task description')
        optional(:skill_name).filled(:string).description('Name of skill to execute')
      end

      def call(title:, scheduled_for:, description: nil, skill_name: nil)
        scheduled_time = parse_time(scheduled_for)

        unless scheduled_time
          return {
            success: false,
            error: "Invalid time format: #{scheduled_for}"
          }
        end

        task = ScheduledTask.create!(
          title: title,
          description: description,
          scheduled_for: scheduled_time,
          skill_name: skill_name
        )

        Ai.logger.info "Scheduled task ##{task.id}: #{title} for #{scheduled_time}"

        {
          success: true,
          task_id: task.id,
          title: task.title,
          scheduled_for: task.scheduled_for.iso8601
        }
      rescue => e
        Ai.logger.error "Failed to schedule task: #{e.message}"
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
