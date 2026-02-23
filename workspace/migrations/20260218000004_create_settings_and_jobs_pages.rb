# frozen_string_literal: true

class CreateSettingsAndJobsPages < ActiveRecord::Migration[8.0]
  def up
    # Settings page
    settings_page = execute(<<~SQL).first
      INSERT INTO ai_pages (title, slug, content, status, published_at, metadata, canvas_state, created_at, updated_at)
      VALUES ('Settings', 'settings', '', 'published', CURRENT_TIMESTAMP, '{}', '{"scroll_locked":true}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
    settings_id = settings_page['id']

    execute(<<~SQL)
      INSERT INTO canvas_components (ai_page_id, component_type, content, x, y, width, height, z_index, metadata, created_at, updated_at)
      VALUES (#{settings_id}, 'settings', '', 0, 0, 1200, NULL, 0, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    # Jobs & Skills page
    jobs_page = execute(<<~SQL).first
      INSERT INTO ai_pages (title, slug, content, status, published_at, metadata, canvas_state, created_at, updated_at)
      VALUES ('Jobs & Skills', 'jobs', '', 'published', CURRENT_TIMESTAMP, '{}', '{"scroll_locked":true}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
    jobs_id = jobs_page['id']

    execute(<<~SQL)
      INSERT INTO canvas_components (ai_page_id, component_type, content, x, y, width, height, z_index, metadata, created_at, updated_at)
      VALUES (#{jobs_id}, 'scheduled_jobs', '', 0, 0, 1200, NULL, 0, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def down
    execute("DELETE FROM canvas_components WHERE ai_page_id IN (SELECT id FROM ai_pages WHERE slug IN ('settings', 'jobs'))")
    execute("DELETE FROM ai_pages WHERE slug IN ('settings', 'jobs')")
  end
end
