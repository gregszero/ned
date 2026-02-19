# frozen_string_literal: true

module Fang
  module Resources
    class AvailableGemsResource < FastMcp::Resource
      uri 'gems://available'
      resource_name 'Available Gems'
      description 'Currently installed Ruby gems and their versions'

      def content
        # Get list of gems from Bundler
        specs = Bundler.load.specs.map do |spec|
          {
            name: spec.name,
            version: spec.version.to_s,
            summary: spec.summary,
            homepage: spec.homepage,
            dependencies: spec.dependencies.map(&:name)
          }
        end

        # Get Gemfile content
        gemfile_path = File.join(Fang.root, 'Gemfile')
        gemfile_content = File.exist?(gemfile_path) ? File.read(gemfile_path) : nil

        {
          total_gems: specs.count,
          gems: specs.sort_by { |g| g[:name] },
          gemfile_path: 'Gemfile',
          gemfile_content: gemfile_content,
          ruby_version: RUBY_VERSION,
          bundler_version: Bundler::VERSION,
          note: 'To add a gem: edit Gemfile and run `bundle install`'
        }.to_json
      end
    end
  end
end
