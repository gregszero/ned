# frozen_string_literal: true

class CreateMcpConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_connections do |t|
      t.string :name, null: false
      t.string :transport_type, null: false  # stdio, sse, http
      t.text :command                        # For stdio
      t.string :url                          # For sse/http
      t.boolean :enabled, default: true
      t.json :available_tools, default: []
      t.json :config, default: {}
      t.timestamps
    end

    add_index :mcp_connections, :name, unique: true
    add_index :mcp_connections, :enabled
  end
end
