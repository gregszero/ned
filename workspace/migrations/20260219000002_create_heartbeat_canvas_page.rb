# frozen_string_literal: true

class CreateHeartbeatCanvasPage < ActiveRecord::Migration[8.0]
  def up
    page = execute(<<~SQL).first
      INSERT INTO ai_pages (title, slug, content, status, published_at, metadata, canvas_state, created_at, updated_at)
      VALUES ('Heartbeats', 'heartbeats', '', 'published', datetime('now'), '{}', '{"scroll_locked":true}', datetime('now'), datetime('now'))
      RETURNING id
    SQL
    page_id = page['id']

    execute(<<~SQL)
      INSERT INTO canvas_components (ai_page_id, component_type, content, x, y, width, height, z_index, metadata, created_at, updated_at)
      VALUES (#{page_id}, 'heartbeat_monitor', '', 0, 0, 1200, NULL, 0, '{}', datetime('now'), datetime('now'))
    SQL
  end

  def down
    execute("DELETE FROM canvas_components WHERE ai_page_id IN (SELECT id FROM ai_pages WHERE slug = 'heartbeats')")
    execute("DELETE FROM ai_pages WHERE slug = 'heartbeats'")
  end
end
