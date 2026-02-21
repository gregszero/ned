# frozen_string_literal: true

module Fang
  module Tools
    class UpdateDataRecordTool < FastMcp::Tool
      tool_name 'update_data_record'
      description 'Update a record in a dynamic data table by record ID'

      arguments do
        required(:data_table_id).filled(:integer).description('Data table ID')
        required(:record_id).filled(:integer).description('Record ID to update')
        required(:attributes).description('Attributes to update as key-value pairs')
      end

      def call(data_table_id:, record_id:, attributes:)
        dt = DataTable.find(data_table_id)
        record = dt.update_record(record_id, attributes)

        {
          success: true,
          record_id: record.id,
          table_name: dt.name,
          attributes: record.attributes.except('created_at', 'updated_at')
        }
      rescue ActiveRecord::RecordNotFound => e
        { success: false, error: e.message }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
