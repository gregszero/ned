# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :container_id
      t.string :status, null: false, default: 'starting'  # starting, running, stopped, error
      t.string :session_path
      t.datetime :started_at
      t.datetime :stopped_at
      t.timestamps
    end

    add_index :sessions, :container_id, unique: true
    add_index :sessions, :status
    add_index :sessions, [:conversation_id, :created_at]
  end
end
