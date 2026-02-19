# frozen_string_literal: true

module Fang
  module Resources
    class ConfigResource < FastMcp::Resource
      uri 'config://user'
      resource_name 'User Configuration'
      description 'User settings and configuration values'

      def content
        config_data = Config.all_config

        # Add useful framework info
        config_data.merge(
          framework_version: '0.1.0',
          ruby_version: RUBY_VERSION,
          environment: Fang.env,
          project_root: Fang.root.to_s
        ).to_json
      end
    end
  end
end
