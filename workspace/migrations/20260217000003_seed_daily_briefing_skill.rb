# frozen_string_literal: true

class SeedDailyBriefingSkill < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      INSERT INTO skills (name, description, file_path, class_name, usage_count, metadata, created_at, updated_at)
      VALUES ('daily_briefing', 'Fetches weather and news, creates a daily briefing page',
              'skills/daily_briefing.rb', 'DailyBriefing', 0, '{}',
              datetime('now'), datetime('now'))
    SQL
  end

  def down
    execute "DELETE FROM skills WHERE name = 'daily_briefing'"
  end
end
