# frozen_string_literal: true

class CreateCanvasComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :canvas_components do |t|
      t.references :ai_page, null: false, foreign_key: true
      t.string :component_type, null: false, default: 'card'
      t.text :content
      t.float :x, null: false, default: 0
      t.float :y, null: false, default: 0
      t.float :width, null: false, default: 320
      t.float :height
      t.integer :z_index, null: false, default: 0
      t.json :metadata, default: {}
      t.timestamps
    end

    add_column :ai_pages, :canvas_state, :json, default: {}
  end
end
