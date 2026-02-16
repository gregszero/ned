# frozen_string_literal: true

module Ai
  module Jobs
    class ScheduledTaskRunnerJob < ApplicationJob
      queue_as :scheduled_tasks

      # Execute a scheduled task
      def perform(task_id)
        task = ScheduledTask.find(task_id)

        Ai.logger.info "Running scheduled task: #{task.title}"

        # Mark as running
        task.mark_running!

        # Execute the task
        result = if task.skill_name.present?
          # Execute via skill
          execute_skill(task)
        else
          # Execute description as instruction
          execute_instruction(task)
        end

        # Mark as completed
        task.mark_completed!(result.to_json)

        Ai.logger.info "Completed scheduled task #{task_id}"

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Scheduled task not found: #{e.message}"
      rescue => e
        Ai.logger.error "Scheduled task execution failed: #{e.message}"
        task&.mark_failed!(e.message)
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
        # Create a new conversation for this task
        conversation = Conversation.create!(
          title: task.title,
          source: 'scheduled_task',
          context: {
            scheduled_task_id: task.id
          }
        )

        # Add the task description as a message
        message = conversation.add_message(
          role: 'user',
          content: task.description || task.title
        )

        # Enqueue agent execution
        AgentExecutorJob.perform_later(message.id)

        {
          conversation_id: conversation.id,
          message_id: message.id,
          status: 'enqueued'
        }
      end
    end
  end
end
