# frozen_string_literal: true

module Fang
  module Tools
    class ManagePythonTool < FastMcp::Tool
      tool_name 'manage_python'
      description 'Manage the Python virtualenv: install packages, list installed packages, or set up the venv'

      arguments do
        required(:action).filled(:string).description('Action: "install", "list", or "setup"')
        optional(:packages).description('Package names to install (for "install" action)')
      end

      def call(action:, packages: nil)
        case action.to_s.downcase
        when 'install'
          pkgs = Array(packages)
          return { success: false, error: 'No packages specified' } if pkgs.empty?

          Fang::PythonRunner.pip_install(*pkgs)
        when 'list'
          Fang::PythonRunner.pip_list
        when 'setup'
          Fang::PythonRunner.ensure_venv!
          { success: true, message: 'Python virtualenv is ready', path: Fang::PythonRunner.venv_path }
        else
          { success: false, error: "Unknown action: #{action}. Use 'install', 'list', or 'setup'." }
        end
      rescue => e
        Fang.logger.error "manage_python failed: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
