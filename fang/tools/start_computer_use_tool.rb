# frozen_string_literal: true

module Fang
  module Tools
    class StartComputerUseTool < FastMcp::Tool
      tool_name 'start_computer_use'
      description 'Launch a computer use session to visually interact with a desktop and browser. Use when you need to browse websites, fill forms, click buttons, or interact with any GUI application.'

      arguments do
        required(:task).filled(:string).description('What to accomplish on the computer')
      end

      def call(task:)
        conversation = if ENV['CONVERSATION_ID']
          Conversation.find(ENV['CONVERSATION_ID'])
        else
          Conversation.last
        end

        unless conversation
          return { success: false, error: 'No conversation found' }
        end

        message = conversation.messages.where(role: 'user').last
        unless message
          return { success: false, error: 'No user message found to attach CUA session to' }
        end

        # Enqueue the CUA job
        Jobs::ComputerUseExecutorJob.perform_later(message.id, task: task)

        Fang.logger.info "Computer use session started for task: #{task[0..80]}"

        {
          success: true,
          message: "Computer use session started. The AI will control a virtual desktop to complete: #{task}",
          conversation_id: conversation.id
        }
      rescue => e
        Fang.logger.error "Failed to start computer use: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
