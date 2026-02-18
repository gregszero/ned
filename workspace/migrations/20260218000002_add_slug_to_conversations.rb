class AddSlugToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :slug, :string
    add_index :conversations, :slug, unique: true

    # Backfill existing conversations
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE conversations
          SET slug = 'chat-' || id
          WHERE slug IS NULL
        SQL
      end
    end
  end
end
