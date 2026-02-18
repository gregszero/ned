# frozen_string_literal: true

class AddAiPageIdToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :ai_page_id, :integer
    add_index :notifications, :ai_page_id
  end
end
