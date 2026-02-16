# frozen_string_literal: true

class CreateScheduledTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_tasks do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :scheduled_for, null: false
      t.string :status, default: 'pending', null: false  # pending, running, completed, failed
      t.text :result
      t.json :parameters, default: {}
      t.string :skill_name
      t.timestamps
    end

    add_index :scheduled_tasks, :scheduled_for
    add_index :scheduled_tasks, :status
    add_index :scheduled_tasks, [:status, :scheduled_for]
  end
end
