# frozen_string_literal: true

module Fang
  module Tools
    class DeleteDataRecordTool < FastMcp::Tool
      tool_name 'delete_data_record'
      description 'Delete a record from a dynamic data table by record ID'

      arguments do
        required(:data_table_id).filled(:integer).description('Data table ID')
        required(:record_id).filled(:integer).description('Record ID to delete')
      end

      def call(data_table_id:, record_id:)
        dt = DataTable.find(data_table_id)
        dt.delete_record(record_id)

        { success: true, deleted_record_id: record_id, table_name: dt.name }
      rescue ActiveRecord::RecordNotFound => e
        { success: false, error: e.message }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
