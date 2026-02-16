# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.string :title, null: false
      t.text :body
      t.string :kind           # info, success, warning, error
      t.string :status, default: 'unread' # unread, read, dismissed
      t.string :action_url     # optional link
      t.integer :conversation_id # optional, links to source conversation
      t.timestamps
    end

    add_index :notifications, :status
    add_index :notifications, :created_at
  end
end
