# frozen_string_literal: true

class ShowcaseSetup < Fang::Skill
  description "Creates the Showcase page demonstrating OpenFang's full capability range"

  WIDGETS = [
    # Row 1 — Hero
    { type: 'banner', x: 20, y: 20, w: 1080, h: nil, meta: {
      'message' => "OpenFang \u2014 AI assistant framework. 40 tools, 25 widgets, endless automation.",
      'banner_type' => 'info'
    }},

    # Row 2 — Live Data
    { type: 'weather', x: 20, y: 100, w: 280, h: nil, meta: {
      'city' => 'Zurich', 'country' => 'CH'
    }},
    { type: 'clock', x: 320, y: 100, w: 200, h: nil, meta: {
      'timezone' => 'UTC', 'label' => 'UTC'
    }},
    { type: 'clock', x: 540, y: 100, w: 200, h: nil, meta: {
      'timezone' => 'Europe/Zurich', 'label' => 'Zurich'
    }},
    { type: 'metric', x: 760, y: 100, w: 280, h: nil, meta: {
      'label' => 'Conversations', 'value' => '—',
      'data_source' => 'Conversation.count'
    }},

    # Row 3 — Visualization
    { type: 'chart', x: 20, y: 320, w: 540, h: 300, meta: {
      'chart_type' => 'bar',
      'title' => 'Widget Types by Category',
      'labels' => %w[Content Data System Automation],
      'datasets' => [{ 'label' => 'Widgets', 'data' => [5, 3, 5, 4],
                       'backgroundColor' => ['#3b82f6', '#f97316', '#16a34a', '#a78bfa'] }]
    }},
    { type: 'hacker_news', x: 580, y: 320, w: 520, h: 300, meta: {
      'story_count' => 5
    }},

    # Row 4 — Automation
    { type: 'heartbeat_monitor', x: 20, y: 660, w: 540, h: nil, meta: {} },
    { type: 'workflow_monitor', x: 580, y: 660, w: 520, h: nil, meta: {} },

    # Row 5 — Interaction
    { type: 'approval', x: 20, y: 960, w: 360, h: nil, meta: {} },
    { type: 'quick_actions', x: 400, y: 960, w: 340, h: nil, meta: {} },
    { type: 'gmail_inbox', x: 760, y: 960, w: 340, h: nil, meta: {} },

    # Row 6 — Data & Content
    { type: 'table', x: 20, y: 1300, w: 540, h: nil, meta: {
      'title' => 'MCP Tool Categories',
      'columns' => %w[Category Tools Description],
      'rows' => [
        ['Core', '4', 'Code execution, skills, messaging'],
        ['Pages & Canvas', '6', 'Page and widget management'],
        ['Documents', '3', 'Upload, read, list documents'],
        ['Data Tables', '5', 'Dynamic SQLite table CRUD'],
        ['Automation', '6', 'Notifications, triggers, workflows, heartbeats'],
        ['Web & Gmail', '7', 'HTTP requests, browser, email'],
        ['Scheduling', '1', 'Future tasks and cron jobs'],
        ['Approvals', '3', 'Human-in-the-loop gates'],
      ]
    }},
    { type: 'list', x: 580, y: 1300, w: 520, h: nil, meta: {
      'title' => 'Key Features',
      'items' => [
        { 'text' => '40 MCP Tools', 'subtitle' => 'Auto-discovered via ObjectSpace' },
        { 'text' => '25+ Widget Types', 'subtitle' => 'Refreshable, draggable canvas components' },
        { 'text' => 'Event Bus', 'subtitle' => 'Triggers and multi-step workflows' },
        { 'text' => 'Real-time Updates', 'subtitle' => 'SSE + Turbo Streams, no Redis needed' },
        { 'text' => 'Claude CLI Agent', 'subtitle' => 'Subprocess per conversation with MCP' },
        { 'text' => 'Python Runtime', 'subtitle' => 'Virtualenv management and code execution' },
        { 'text' => 'Browser Automation', 'subtitle' => 'Playwright-based computer use' },
        { 'text' => 'Gmail Integration', 'subtitle' => 'OAuth2 search, read, send, draft' },
      ]
    }},

    # Row 7 — System
    { type: 'system_overview', x: 20, y: 1620, w: 520, h: nil, meta: {} },
    { type: 'docker_containers', x: 560, y: 1620, w: 540, h: nil, meta: {} },
  ].freeze

  def call
    page = find_or_create_page
    page.canvas_components.destroy_all

    WIDGETS.each_with_index do |w, i|
      page.canvas_components.create!(
        component_type: w[:type],
        content: '',
        x: w[:x], y: w[:y],
        width: w[:w],
        height: w[:h],
        z_index: i,
        metadata: w[:meta]
      )
    end

    refresh_widgets(page)
    create_notification(page)

    { success: true, page_url: "/#{page.slug}" }
  end

  private

  def find_or_create_page
    page = Fang::Page.find_by(slug: "showcase")
    unless page
      page = Fang::Page.create!(
        title: "Showcase",
        slug: "showcase",
        content: '',
        status: "published",
        published_at: Time.current
      )
    end
    page
  end

  def refresh_widgets(page)
    page.canvas_components.find_each do |component|
      widget_class = Fang::Widgets::BaseWidget.for_type(component.component_type)
      next unless widget_class&.refreshable?

      widget = widget_class.new(component)
      if widget.refresh_data!
        turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                "<template>#{widget.render_component_html}</template></turbo-stream>"
        Fang::Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
      end
    rescue => e
      Fang.logger.error "Showcase widget refresh failed: #{e.message}"
    end
  end

  def create_notification(page)
    Fang::Notification.create!(
      title: "Showcase is ready",
      body: "Your showcase with #{WIDGETS.size} widgets is live at /#{page.slug}",
      kind: "info",
      status: "unread"
    ).broadcast!
  end
end
