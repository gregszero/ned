# frozen_string_literal: true

class SeedCommandCenterPage < ActiveRecord::Migration[8.0]
  def up
    page = execute(<<~SQL).first
      INSERT INTO pages (title, slug, content, status, published_at, metadata, canvas_state, created_at, updated_at)
      VALUES ('Command Center', 'command-center', '', 'published', CURRENT_TIMESTAMP, '{}', '{"scroll_locked":true}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
    page_id = page['id']

    widgets = [
      # Row 1
      { type: 'system_overview',   x: 20,  y: 20,  w: 680, h: 'NULL', z: 0, meta: '{}' },
      { type: 'clock',             x: 720, y: 20,  w: 200, h: 'NULL', z: 1, meta: '{"timezone":"Europe/Zurich","label":"Zurich"}' },
      # Row 2
      { type: 'gmail_inbox',       x: 20,  y: 260, w: 380, h: 320,    z: 2, meta: '{}' },
      { type: 'workflow_monitor',  x: 420, y: 260, w: 380, h: 320,    z: 3, meta: '{}' },
      { type: 'quick_actions',     x: 820, y: 260, w: 280, h: 320,    z: 4, meta: '{}' },
      # Row 3
      { type: 'heartbeat_monitor', x: 20,  y: 620, w: 580, h: 'NULL', z: 5, meta: '{}' },
      { type: 'approval',          x: 620, y: 620, w: 480, h: 'NULL', z: 6, meta: '{}' },
    ]

    widgets.each do |w|
      execute(<<~SQL)
        INSERT INTO canvas_components (page_id, component_type, content, x, y, width, height, z_index, metadata, created_at, updated_at)
        VALUES (#{page_id}, '#{w[:type]}', '', #{w[:x]}, #{w[:y]}, #{w[:w]}, #{w[:h]}, #{w[:z]}, '#{w[:meta]}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end
  end

  def down
    execute("DELETE FROM canvas_components WHERE page_id IN (SELECT id FROM pages WHERE slug = 'command-center')")
    execute("DELETE FROM pages WHERE slug = 'command-center'")
  end
end
