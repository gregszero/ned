# frozen_string_literal: true

module Fang
  module Tools
    class InsertDataRecordTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'insert_data_record'
      description 'Insert a record into a dynamic data table'
      tool_group :data

      arguments do
        required(:data_table_id).filled(:integer).description('Data table ID')
        required(:attributes).description('Record attributes as key-value pairs matching the table schema')
      end

      def call(data_table_id:, attributes:)
        dt = DataTable.find(data_table_id)
        record = dt.insert_record(attributes)

        {
          success: true,
          record_id: record.id,
          table_name: dt.name,
          attributes: record.attributes.except('created_at', 'updated_at')
        }
      rescue ActiveRecord::RecordNotFound
        { success: false, error: "Data table #{data_table_id} not found" }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
