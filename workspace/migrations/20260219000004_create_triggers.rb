# frozen_string_literal: true

class CreateTriggers < ActiveRecord::Migration[8.0]
  def change
    create_table :triggers do |t|
      t.string :name, null: false
      t.string :event_pattern, null: false
      t.string :action_type, null: false
      t.text :action_config
      t.boolean :enabled, default: true
      t.integer :fire_count, default: 0
      t.integer :consecutive_failures, default: 0
      t.datetime :last_fired_at
      t.timestamps
    end
  end
end
