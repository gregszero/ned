# frozen_string_literal: true

class DailyBriefing < Fang::Skill
  description "Creates a daily briefing canvas with weather and news widgets"
  param :city, :string, required: false, description: "City for weather (default: Zurich)"

  def call(city: nil)
    city ||= Fang::Config.get("briefing_city") || "Zurich"

    page = find_or_create_page
    ensure_weather_widget(page, city)
    ensure_hacker_news_widget(page)
    refresh_widgets(page)
    create_notification(page)
    reschedule_for_tomorrow

    { success: true, page_url: "/#{page.slug}" }
  end

  private

  def find_or_create_page
    page = Fang::Page.find_by(slug: "daily-briefing")
    unless page
      page = Fang::Page.create!(
        title: "Daily Briefing",
        slug: "daily-briefing",
        content: '',
        status: "published",
        published_at: Time.current
      )
    end
    page
  end

  def ensure_weather_widget(page, city)
    existing = page.canvas_components.find_by(component_type: 'weather')
    return existing if existing

    page.canvas_components.create!(
      component_type: 'weather',
      content: '',
      x: 20, y: 20,
      width: 280,
      z_index: 0,
      metadata: { 'city' => city, 'country' => 'CH' }
    )
  end

  def ensure_hacker_news_widget(page)
    existing = page.canvas_components.find_by(component_type: 'hacker_news')
    return existing if existing

    page.canvas_components.create!(
      component_type: 'hacker_news',
      content: '',
      x: 320, y: 20,
      width: 320,
      z_index: 0,
      metadata: { 'count' => 5 }
    )
  end

  def refresh_widgets(page)
    page.canvas_components.where(component_type: %w[weather hacker_news]).find_each do |component|
      widget_class = Fang::Widgets::BaseWidget.for_type(component.component_type)
      next unless widget_class

      widget = widget_class.new(component)
      if widget.refresh_data!
        turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                "<template>#{widget.render_component_html}</template></turbo-stream>"
        Fang::Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
      end
    rescue => e
      Fang.logger.error "Daily briefing widget refresh failed: #{e.message}"
    end
  end

  def create_notification(page)
    Fang::Notification.create!(
      title: "Your morning briefing is ready",
      body: "Weather and top stories for today.",
      kind: "info",
      status: "unread"
    ).broadcast!
  end

  def reschedule_for_tomorrow
    hour = (Fang::Config.get("briefing_hour") || "7").to_i
    tomorrow = Time.now + 86400
    scheduled_time = Time.new(tomorrow.year, tomorrow.month, tomorrow.day, hour, 0, 0)

    Fang::ScheduledTask.create!(
      title: "Daily Briefing",
      description: "Run the daily briefing skill",
      scheduled_for: scheduled_time,
      skill_name: "daily_briefing",
      parameters: {}
    )
  end
end
