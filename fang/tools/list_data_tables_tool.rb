# frozen_string_literal: true

module Fang
  module Tools
    class ListDataTablesTool < FastMcp::Tool
      tool_name 'list_data_tables'
      description 'List all dynamic data tables with record counts'

      arguments do
        optional(:status).filled(:string).description('Filter by status: active (default), archived')
      end

      def call(status: 'active')
        tables = DataTable.where(status: status).recent.map do |dt|
          {
            id: dt.id,
            name: dt.name,
            table_name: dt.table_name,
            columns: dt.parsed_schema,
            record_count: dt.record_count,
            description: dt.description,
            status: dt.status,
            created_at: dt.created_at.iso8601
          }
        end

        { success: true, tables: tables, count: tables.length }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
