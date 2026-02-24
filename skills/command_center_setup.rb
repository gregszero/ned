# frozen_string_literal: true

class CommandCenterSetup < Fang::Skill
  description "Creates the Command Center dashboard with system monitoring widgets"

  WIDGETS = [
    # Row 1
    { type: 'system_overview',    x: 20,  y: 20,  w: 680, h: nil, meta: {} },
    { type: 'clock',              x: 720, y: 20,  w: 200, h: nil, meta: { 'timezone' => 'Europe/Zurich', 'label' => 'Zurich' } },
    # Row 2
    { type: 'gmail_inbox',        x: 20,  y: 260, w: 380, h: 320, meta: {} },
    { type: 'workflow_monitor',   x: 420, y: 260, w: 380, h: 320, meta: {} },
    { type: 'quick_actions',      x: 820, y: 260, w: 280, h: 320, meta: {} },
    # Row 3
    { type: 'heartbeat_monitor',  x: 20,  y: 620, w: 580, h: nil, meta: {} },
    { type: 'approval',           x: 620, y: 620, w: 480, h: nil, meta: {} },
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
    page = Fang::Page.find_by(slug: "command-center")
    unless page
      page = Fang::Page.create!(
        title: "Command Center",
        slug: "command-center",
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
      Fang.logger.error "Command center widget refresh failed: #{e.message}"
    end
  end

  def create_notification(page)
    Fang::Notification.create!(
      title: "Command Center is ready",
      body: "Your dashboard with 7 widgets is live at /#{page.slug}",
      kind: "info",
      status: "unread"
    ).broadcast!
  end
end
