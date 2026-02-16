# frozen_string_literal: true

module Ai
  class McpConnection < ActiveRecord::Base
    self.table_name = 'mcp_connections'

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :transport_type, presence: true, inclusion: { in: %w[stdio sse http] }
    validate :transport_configuration_valid

    # Scopes
    scope :enabled, -> { where(enabled: true) }
    scope :by_transport, ->(type) { where(transport_type: type) }

    # Callbacks
    before_create :set_defaults

    # Methods
    def enable!
      update!(enabled: true)
    end

    def disable!
      update!(enabled: false)
    end

    def stdio?
      transport_type == 'stdio'
    end

    def sse?
      transport_type == 'sse'
    end

    def http?
      transport_type == 'http'
    end

    def connection_string
      case transport_type
      when 'stdio'
        command
      when 'sse', 'http'
        url
      end
    end

    def test_connection
      # Placeholder for connection testing
      # Will be implemented when MCP server is ready
      true
    end

    private

    def set_defaults
      self.config ||= {}
      self.available_tools ||= []
    end

    def transport_configuration_valid
      case transport_type
      when 'stdio'
        errors.add(:command, "can't be blank for stdio transport") if command.blank?
      when 'sse', 'http'
        errors.add(:url, "can't be blank for #{transport_type} transport") if url.blank?
      end
    end
  end
end
