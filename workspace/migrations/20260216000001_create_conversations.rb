# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.string :title
      t.string :source, default: 'web', null: false  # web, cli
      t.datetime :last_message_at
      t.json :context, default: {}
      t.timestamps
    end

    add_index :conversations, :source
    add_index :conversations, :last_message_at
  end
end
