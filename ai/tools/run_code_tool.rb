# frozen_string_literal: true

module Ai
  module Tools
    class RunCodeTool < FastMcp::Tool
      tool_name 'run_code'
      description 'Execute Ruby code directly in a safe context'

      arguments do
        required(:ruby_code).filled(:string).description('Ruby code to execute')
        optional(:description).filled(:string).description('Brief description of what this code does')
      end

      def call(ruby_code:, description: nil)
        Ai.logger.info "Executing Ruby code: #{description || 'No description'}"

        context = create_safe_context
        result = context.eval(ruby_code)

        {
          success: true,
          result: result.inspect,
          output: result.to_s
        }
      rescue SyntaxError => e
        { success: false, error: "Syntax error: #{e.message}" }
      rescue => e
        Ai.logger.error "Code execution failed: #{e.message}"
        { success: false, error: e.message, backtrace: e.backtrace.first(5) }
      end

      private

      def create_safe_context
        ctx = Object.new
        Ai.constants.map { |c| Ai.const_get(c) }
          .select { |c| c.is_a?(Class) && c < ActiveRecord::Base }
          .each { |model| ctx.define_singleton_method(model.name.demodulize.to_sym) { model } }
        ctx.instance_eval { binding }
      end
    end
  end
end
