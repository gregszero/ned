# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.text :content, null: false
      t.string :role, null: false       # user, assistant, system
      t.boolean :streaming, default: false
      t.json :metadata, default: {}    # Attachments, tool calls
      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, :role
  end
end
