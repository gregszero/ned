# frozen_string_literal: true

class AddContextSummaryToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :context_summary, :text
    add_column :conversations, :summary_message_count, :integer, default: 0
  end
end
