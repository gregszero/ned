# frozen_string_literal: true

module Ai
  module Jobs
    class ScheduledTaskRunnerJob < ApplicationJob
      queue_as :scheduled_tasks

      # Execute a scheduled task and feed results back to the conversation
      def perform(task_id)
        task = ScheduledTask.find(task_id)

        Ai.logger.info "Running scheduled task: #{task.title}"

        task.mark_running!

        result = if task.skill_name.present?
          execute_skill(task)
        else
          execute_instruction(task)
        end

        task.mark_completed!(result.to_json)
        task.schedule_next_run! if task.recurring?

        # Feed result back to the originating conversation so the AI knows what happened
        feed_result_to_conversation(task, result)

        # Create success notification
        notification = Notification.create!(
          title: "Task completed: #{task.title}",
          body: "Scheduled task '#{task.title}' finished successfully.",
          kind: 'success',
          conversation_id: task.respond_to?(:conversation_id) ? task.conversation_id : nil
        )
        notification.broadcast!

        Ai.logger.info "Completed scheduled task #{task_id}"
        EventBus.emit("task:completed:#{task.title.parameterize}", { task_id: task.id, title: task.title })

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Scheduled task not found: #{e.message}"
      rescue => e
        Ai.logger.error "Scheduled task execution failed: #{e.message}"
        task&.mark_failed!(e.message)
        EventBus.emit("task:failed:#{task&.title&.parameterize}", { task_id: task&.id, error: e.message }) if task
        feed_error_to_conversation(task, e.message) if task

        # Create error notification
        if task
          notification = Notification.create!(
            title: "Task failed: #{task.title}",
            body: e.message,
            kind: 'error',
            conversation_id: task.respond_to?(:conversation_id) ? task.conversation_id : nil
          )
          notification.broadcast!
        end
      end

      private

      def execute_skill(task)
        skill_record = SkillRecord.find_by(name: task.skill_name)

        unless skill_record
          raise "Skill not found: #{task.skill_name}"
        end

        # Execute the skill with parameters
        result = skill_record.load_and_execute(**(task.parameters || {}))

        {
          skill_name: task.skill_name,
          result: result
        }
      end

      def execute_instruction(task)
        conversation = find_or_create_conversation(task)

        message = conversation.add_message(
          role: 'user',
          content: task.description || task.title
        )

        AgentExecutorJob.perform_later(message.id)

        {
          conversation_id: conversation.id,
          message_id: message.id,
          status: 'enqueued'
        }
      end

      def find_or_create_conversation(task)
        if task.respond_to?(:conversation_id) && task.conversation_id
          Conversation.find(task.conversation_id)
        else
          Conversation.create!(
            title: task.title,
            source: 'scheduled_task',
            context: { scheduled_task_id: task.id }
          )
        end
      end

      def feed_result_to_conversation(task, result)
        conversation = find_or_create_conversation(task)

        conversation.add_message(
          role: 'system',
          content: "Scheduled task '#{task.title}' completed:\n```json\n#{result.to_json}\n```"
        )
      end

      def feed_error_to_conversation(task, error_message)
        conversation = find_or_create_conversation(task)
        conversation.add_message(
          role: 'system',
          content: "Scheduled task '#{task.title}' failed: #{error_message}"
        )
      rescue => e
        Ai.logger.error "Failed to feed error back to conversation: #{e.message}"
      end
    end
  end
end
