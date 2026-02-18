# frozen_string_literal: true

class AddRecurringToScheduledTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :scheduled_tasks, :cron_expression, :string
    add_column :scheduled_tasks, :recurring, :boolean, default: false
    add_column :scheduled_tasks, :last_completed_at, :datetime
  end
end
