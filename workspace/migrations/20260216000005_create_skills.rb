# frozen_string_literal: true

class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.string :name, null: false
      t.text :description
      t.string :file_path, null: false  # Path to .rb file
      t.string :class_name              # Ruby class name
      t.integer :usage_count, default: 0
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :skills, :name, unique: true
    add_index :skills, :usage_count
  end
end
