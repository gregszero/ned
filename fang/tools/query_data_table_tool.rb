# frozen_string_literal: true

module Fang
  module Tools
    class QueryDataTableTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'query_data_table'
      description 'Query records from a dynamic data table with filtering, sorting, and pagination'
      tool_group :data

      arguments do
        required(:data_table_id).filled(:integer).description('Data table ID')
        optional(:filters).description('Array of filters: [{"column":"name","operator":"=","value":"Alice"}]. Operators: =, !=, >, <, like')
        optional(:sort_by).filled(:string).description('Column to sort by')
        optional(:sort_dir).filled(:string).description('Sort direction: asc (default) or desc')
        optional(:page).filled(:integer).description('Page number (default 1)')
        optional(:per_page).filled(:integer).description('Records per page (default 25)')
      end

      def call(data_table_id:, filters: nil, sort_by: nil, sort_dir: 'asc', page: 1, per_page: 25)
        dt = DataTable.find(data_table_id)
        records = dt.query_records(
          filters: filters,
          sort_by: sort_by,
          sort_dir: sort_dir,
          page: page,
          per_page: per_page
        )

        rows = records.map do |r|
          attrs = r.attributes
          attrs.delete('created_at')
          attrs.delete('updated_at')
          attrs
        end

        {
          success: true,
          table_name: dt.name,
          records: rows,
          count: rows.length,
          page: page,
          per_page: per_page
        }
      rescue ActiveRecord::RecordNotFound
        { success: false, error: "Data table #{data_table_id} not found" }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
