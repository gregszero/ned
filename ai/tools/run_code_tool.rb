# frozen_string_literal: true

module Ai
  module Tools
    class RunCodeTool
      include FastMcp::Tool

      tool_name 'run_code'
      description 'Execute Ruby code directly in a safe context'

      parameter :ruby_code, type: 'string', description: 'Ruby code to execute', required: true
      parameter :description, type: 'string', description: 'Brief description of what this code does', required: false

      def call(ruby_code:, description: nil)
        Ai.logger.info "Executing Ruby code: #{description || 'No description'}"

        # Create a safe binding with access to models and helpers
        context = create_safe_context

        # Execute code
        result = context.eval(ruby_code)

        {
          success: true,
          result: result.inspect,
          output: result.to_s
        }
      rescue SyntaxError => e
        {
          success: false,
          error: "Syntax error: #{e.message}"
        }
      rescue => e
        Ai.logger.error "Code execution failed: #{e.message}"
        {
          success: false,
          error: e.message,
          backtrace: e.backtrace.first(5)
        }
      end

      private

      def create_safe_context
        # Create a binding with access to useful classes
        binding_context = Object.new

        # Make models available
        binding_context.instance_eval do
          def Conversation; Ai::Conversation; end
          def Message; Ai::Message; end
          def Session; Ai::Session; end
          def ScheduledTask; Ai::ScheduledTask; end
          def SkillRecord; Ai::SkillRecord; end
          def McpConnection; Ai::McpConnection; end
          def Config; Ai::Config; end
        end

        binding_context.instance_eval { binding }
      end
    end
  end
end
