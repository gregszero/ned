# frozen_string_literal: true

module Fang
  module Resources
    class SystemProfileResource < FastMcp::Resource
      uri 'system://profile'
      resource_name 'System Profile'
      description 'Host system info: OS, hardware, CLI tools, services, network, and environment'

      def content
        data = SystemProfile.to_h
        profile = data[:profile] || {}

        summary = build_summary(profile)
        data.merge(summary: summary).to_json
      end

      private

      def build_summary(profile)
        parts = []

        os = profile[:os]
        parts << (os[:distribution] || "#{os[:id]} #{os[:version]}") if os

        hostname = profile.dig(:hostname, :hostname)
        parts << hostname if hostname

        cpu = profile.dig(:hardware, :cpu)
        parts << "#{cpu[:model]} (#{cpu[:cores]} cores)" if cpu&.dig(:model)

        mem = profile.dig(:hardware, :memory)
        parts << "#{mem[:total_mb]}MB RAM" if mem&.dig(:total_mb)

        tools = profile[:cli_tools]
        if tools&.any?
          notable = %w[git ruby python3 node claude curl].select { |t| tools.key?(t) }
          parts << "#{tools.size} CLI tools (#{notable.join(', ')})"
        end

        parts.join(' | ')
      end
    end
  end
end
