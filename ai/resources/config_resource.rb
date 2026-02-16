# frozen_string_literal: true

module Ai
  module Resources
    class ConfigResource
      include FastMcp::Resource

      resource_uri 'config://user'
      resource_name 'User Configuration'
      description 'User settings and configuration values'

      def read
        config_data = Config.all_config

        # Add useful framework info
        config_data.merge(
          framework_version: '0.1.0',
          ruby_version: RUBY_VERSION,
          environment: Ai.env,
          project_root: Ai.root.to_s
        ).to_json
      end
    end
  end
end
