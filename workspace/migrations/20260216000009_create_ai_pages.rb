# frozen_string_literal: true

class CreateAiPages < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_pages do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content, null: false
      t.string :status, default: 'draft', null: false  # draft, published, archived
      t.datetime :published_at
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :ai_pages, :slug, unique: true
    add_index :ai_pages, :status
    add_index :ai_pages, [:status, :published_at]
  end
end
