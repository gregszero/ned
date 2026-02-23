# frozen_string_literal: true

class AddSchedulerWidgetToJobsPage < ActiveRecord::Migration[8.0]
  def up
    jobs_page = execute("SELECT id FROM pages WHERE slug = 'jobs' LIMIT 1").first
    return unless jobs_page

    jobs_id = jobs_page['id']

    execute(<<~SQL)
      INSERT INTO canvas_components (page_id, component_type, content, x, y, width, height, z_index, metadata, created_at, updated_at)
      VALUES (#{jobs_id}, 'scheduler', '', 0, 600, 1200, NULL, 0, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def down
    execute("DELETE FROM canvas_components WHERE component_type = 'scheduler'")
  end
end
