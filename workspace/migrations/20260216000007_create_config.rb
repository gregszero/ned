# frozen_string_literal: true

class CreateConfig < ActiveRecord::Migration[8.0]
  def change
    create_table :config do |t|
      t.string :key, null: false
      t.text :value
      t.string :value_type, default: 'string', null: false  # string, json, encrypted
      t.text :description
      t.timestamps
    end

    add_index :config, :key, unique: true
  end
end
