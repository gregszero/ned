# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.string :content_type
      t.integer :file_size
      t.string :file_path, null: false
      t.string :status, default: 'uploaded', null: false
      t.text :description
      t.text :extracted_text
      t.text :metadata
      t.references :page, foreign_key: { to_table: :pages }, null: true
      t.references :conversation, foreign_key: true, null: true
      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :content_type
  end
end
