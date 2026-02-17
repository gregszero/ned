# frozen_string_literal: true

module Ai
  module Resources
    class DatabaseSchemaResource < FastMcp::Resource
      uri 'database://schema'
      resource_name 'Database Schema'
      description 'Current database tables, columns, and relationships'

      def content
        connection = ActiveRecord::Base.connection

        tables_data = connection.tables.reject do |table|
          table == 'schema_migrations' || table == 'ar_internal_metadata'
        end.map do |table_name|
          columns = connection.columns(table_name).map do |col|
            {
              name: col.name,
              type: col.type,
              sql_type: col.sql_type,
              null: col.null,
              default: col.default,
              primary_key: col.name == 'id'
            }
          end

          indexes = connection.indexes(table_name).map do |idx|
            {
              name: idx.name,
              columns: idx.columns,
              unique: idx.unique
            }
          end

          {
            name: table_name,
            columns: columns,
            indexes: indexes,
            row_count: connection.select_value("SELECT COUNT(*) FROM #{table_name}")
          }
        end

        {
          database_adapter: connection.adapter_name,
          total_tables: tables_data.count,
          tables: tables_data,
          models: {
            'Conversation' => 'Ai::Conversation',
            'Message' => 'Ai::Message',
            'Session' => 'Ai::Session',
            'ScheduledTask' => 'Ai::ScheduledTask',
            'SkillRecord' => 'Ai::SkillRecord',
            'McpConnection' => 'Ai::McpConnection',
            'Config' => 'Ai::Config'
          }
        }.to_json
      end
    end
  end
end
