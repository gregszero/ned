class LinkConversationsToAiPages < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :ai_page_id, :integer
    add_index :conversations, :ai_page_id
    remove_column :conversations, :canvas_html, :text
  end
end
