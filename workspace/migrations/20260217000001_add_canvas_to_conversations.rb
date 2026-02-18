class AddCanvasToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :canvas_html, :text
  end
end
