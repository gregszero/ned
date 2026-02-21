# frozen_string_literal: true

class CreateApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :approvals do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'pending', null: false
      t.string :decision_notes
      t.datetime :decided_at
      t.datetime :expires_at
      t.references :workflow, foreign_key: true, null: true
      t.references :workflow_step, foreign_key: true, null: true
      t.references :notification, foreign_key: true, null: true
      t.references :page, foreign_key: { to_table: :pages }, null: true
      t.text :metadata
      t.timestamps
    end

    add_index :approvals, :status
  end
end
