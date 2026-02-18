# frozen_string_literal: true

class CreateHeartbeats < ActiveRecord::Migration[8.0]
  def change
    create_table :heartbeats do |t|
      t.string :name, null: false
      t.text :description
      t.string :skill_name, null: false
      t.integer :frequency, null: false, default: 300
      t.text :prompt_template
      t.string :status, null: false, default: 'active'
      t.boolean :enabled, null: false, default: true
      t.references :ai_page, foreign_key: true
      t.datetime :last_run_at
      t.integer :run_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :heartbeats, :name, unique: true
    add_index :heartbeats, [:enabled, :status]

    create_table :heartbeat_runs do |t|
      t.references :heartbeat, null: false, foreign_key: true
      t.string :status, null: false
      t.text :result
      t.text :error_message
      t.boolean :escalated, null: false, default: false
      t.integer :duration_ms
      t.datetime :ran_at, null: false
    end

    add_index :heartbeat_runs, [:heartbeat_id, :ran_at]
  end
end
