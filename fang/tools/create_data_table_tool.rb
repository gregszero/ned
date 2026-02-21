# frozen_string_literal: true

module Fang
  module Tools
    class CreateDataTableTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'create_data_table'
      description 'Create a dynamic data table with a custom schema. Creates a real SQLite table for full SQL queryability.'
      tool_group :data

      arguments do
        required(:name).filled(:string).description('Human-readable table name (e.g. "Customers")')
        required(:columns).description('Array of column definitions: [{"name":"email","type":"string","required":true}]. Types: string, text, integer, decimal, boolean, date, datetime, json')
        optional(:description).filled(:string).description('Table description')
      end

      ALLOWED_TYPES = %w[string text integer decimal boolean date datetime json].freeze

      def call(name:, columns:, description: nil)
        table_name = "dt_#{name.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').chomp('_')}"

        # Validate column types
        columns.each do |col|
          col_type = col['type'] || col[:type] || 'string'
          unless ALLOWED_TYPES.include?(col_type)
            return { success: false, error: "Invalid column type '#{col_type}'. Allowed: #{ALLOWED_TYPES.join(', ')}" }
          end
        end

        # Normalize columns
        normalized = columns.map do |col|
          {
            'name' => (col['name'] || col[:name]).to_s,
            'type' => (col['type'] || col[:type] || 'string').to_s,
            'required' => col['required'] || col[:required] || false
          }
        end

        dt = DataTable.create!(
          name: name,
          table_name: table_name,
          schema_definition: normalized.to_json,
          description: description
        )

        dt.create_physical_table!

        {
          success: true,
          data_table_id: dt.id,
          name: dt.name,
          table_name: dt.table_name,
          columns: normalized
        }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
