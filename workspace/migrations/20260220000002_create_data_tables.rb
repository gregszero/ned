# frozen_string_literal: true

class CreateDataTables < ActiveRecord::Migration[8.0]
  def change
    create_table :data_tables do |t|
      t.string :name, null: false
      t.string :table_name, null: false
      t.text :schema_definition, null: false
      t.text :description
      t.string :status, default: 'active', null: false
      t.references :page, foreign_key: { to_table: :pages }, null: true
      t.timestamps
    end

    add_index :data_tables, :table_name, unique: true
    add_index :data_tables, :status
  end
end
