# frozen_string_literal: true

module Fang
  module Tools
    class RunCodeTool < FastMcp::Tool
      tool_name 'run_code'
      description 'Execute code directly. Supports Ruby (with ActiveRecord model access) and Python (with virtualenv packages).'

      arguments do
        required(:code).filled(:string).description('Code to execute')
        optional(:language).filled(:string).description('Language: "ruby" (default) or "python"')
        optional(:description).filled(:string).description('Brief description of what this code does')
      end

      def call(code:, language: 'ruby', description: nil)
        Fang.logger.info "Executing #{language} code: #{description || 'No description'}"

        case language.to_s.downcase
        when 'ruby'
          execute_ruby(code)
        when 'python'
          Fang::PythonRunner.run_code(code)
        else
          { success: false, error: "Unsupported language: #{language}. Use 'ruby' or 'python'." }
        end
      rescue => e
        Fang.logger.error "Code execution failed: #{e.message}"
        { success: false, error: e.message, backtrace: e.backtrace&.first(5) }
      end

      private

      def execute_ruby(code)
        context = create_safe_context
        result = context.eval(code)

        {
          success: true,
          result: result.inspect,
          output: result.to_s
        }
      rescue SyntaxError => e
        { success: false, error: "Syntax error: #{e.message}" }
      end

      def create_safe_context
        ctx = Object.new
        Fang.constants.map { |c| Fang.const_get(c) }
          .select { |c| c.is_a?(Class) && c < ActiveRecord::Base }
          .each { |model| ctx.define_singleton_method(model.name.demodulize.to_sym) { model } }
        ctx.instance_eval { binding }
      end
    end
  end
end
