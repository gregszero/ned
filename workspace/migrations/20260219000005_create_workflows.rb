# frozen_string_literal: true

class CreateWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :workflows do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'pending'
      t.integer :current_step_index, default: 0
      t.text :context
      t.references :conversation, foreign_key: { to_table: :conversations }
      t.string :trigger_event
      t.timestamps
    end

    create_table :workflow_steps do |t|
      t.references :workflow, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name
      t.string :step_type, null: false
      t.text :config
      t.string :status, default: 'pending'
      t.text :result
      t.timestamps
    end
  end
end
