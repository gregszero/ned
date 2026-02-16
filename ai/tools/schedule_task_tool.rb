# frozen_string_literal: true

module Ai
  module Tools
    class ScheduleTaskTool
      include FastMcp::Tool

      tool_name 'schedule_task'
      description 'Schedule a task to run at a specific time in the future'

      parameter :title, type: 'string', description: 'Task title', required: true
      parameter :description, type: 'string', description: 'Detailed task description', required: false
      parameter :scheduled_for, type: 'string', description: 'ISO8601 timestamp or relative time (e.g., "2 hours", "tomorrow")', required: true
      parameter :skill_name, type: 'string', description: 'Name of skill to execute', required: false
      parameter :parameters, type: 'object', description: 'Parameters to pass to the skill', required: false

      def call(title:, scheduled_for:, description: nil, skill_name: nil, parameters: {})
        # Parse scheduled_for time
        scheduled_time = parse_time(scheduled_for)

        unless scheduled_time
          return {
            success: false,
            error: "Invalid time format: #{scheduled_for}"
          }
        end

        # Create scheduled task
        task = ScheduledTask.create!(
          title: title,
          description: description,
          scheduled_for: scheduled_time,
          skill_name: skill_name,
          parameters: parameters || {}
        )

        Ai.logger.info "Scheduled task ##{task.id}: #{title} for #{scheduled_time}"

        {
          success: true,
          task_id: task.id,
          title: task.title,
          scheduled_for: task.scheduled_for.iso8601,
          skill_name: skill_name
        }
      rescue => e
        Ai.logger.error "Failed to schedule task: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end

      private

      def parse_time(time_string)
        # Try ISO8601 first
        begin
          return Time.parse(time_string)
        rescue ArgumentError
          # Continue to relative time parsing
        end

        # Parse relative times
        case time_string.downcase
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
        else
          nil
        end
      end
    end
  end
end
