# frozen_string_literal: true

class RenameAiPagesToPages < ActiveRecord::Migration[8.0]
  def change
    rename_table :ai_pages, :pages
    rename_column :conversations, :ai_page_id, :page_id
    rename_column :notifications, :ai_page_id, :page_id
    rename_column :canvas_components, :ai_page_id, :page_id
  end
end
