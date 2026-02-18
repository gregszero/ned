# frozen_string_literal: true

require 'net/http'
require 'json'

class DailyBriefing < Ai::Skill
  description "Fetches weather and news, creates a daily briefing page"
  param :city, :string, required: false, description: "City for weather (default: Zurich)"

  def call(city: nil)
    city ||= Ai::Config.get("briefing_city") || "Zurich"

    weather = fetch_weather(city)
    news = fetch_news
    html = build_briefing_html(city, weather, news)
    page = upsert_page(html)
    create_notification(page)
    reschedule_for_tomorrow

    { success: true, page_url: "/pages/#{page.slug}" }
  end

  private

  def fetch_weather(city)
    uri = URI("https://wttr.in/#{URI.encode_www_form_component(city)}?format=j1")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    current = data["current_condition"]&.first || {}
    {
      temp_c: current["temp_C"],
      feels_like_c: current["FeelsLikeC"],
      humidity: current["humidity"],
      description: current.dig("weatherDesc", 0, "value"),
      wind_kmph: current["windspeedKmph"],
      wind_dir: current["winddir16Point"]
    }
  rescue => e
    Ai.logger.error "Weather fetch failed: #{e.message}"
    { error: e.message }
  end

  def fetch_news
    uri = URI("https://hacker-news.firebaseio.com/v0/topstories.json")
    response = Net::HTTP.get(uri)
    story_ids = JSON.parse(response).first(5)

    story_ids.map do |id|
      story_uri = URI("https://hacker-news.firebaseio.com/v0/item/#{id}.json")
      story_data = JSON.parse(Net::HTTP.get(story_uri))
      {
        title: story_data["title"],
        url: story_data["url"],
        score: story_data["score"]
      }
    end
  rescue => e
    Ai.logger.error "News fetch failed: #{e.message}"
    []
  end

  def build_briefing_html(city, weather, news)
    date = Time.now.strftime("%A, %B %-d, %Y")

    html = <<~HTML
      <div class="space-y-6">
        <p class="text-sm text-[var(--muted-foreground)]">#{date}</p>

        <div class="card p-4">
          <h2 class="section-heading">Weather in #{city}</h2>
    HTML

    if weather[:error]
      html += "      <p class=\"text-[var(--muted-foreground)]\">Could not fetch weather: #{weather[:error]}</p>\n"
    else
      html += <<~HTML
              <div class="grid grid-cols-2 gap-3 mt-3">
                <div>
                  <p class="text-2xl font-semibold">#{weather[:temp_c]}&deg;C</p>
                  <p class="text-sm text-[var(--muted-foreground)]">Feels like #{weather[:feels_like_c]}&deg;C</p>
                </div>
                <div class="text-sm space-y-1">
                  <p>#{weather[:description]}</p>
                  <p>Humidity: #{weather[:humidity]}%</p>
                  <p>Wind: #{weather[:wind_kmph]} km/h #{weather[:wind_dir]}</p>
                </div>
              </div>
      HTML
    end

    html += <<~HTML
          </div>

          <div class="card p-4">
            <h2 class="section-heading">Top Stories</h2>
    HTML

    if news.empty?
      html += "      <p class=\"text-[var(--muted-foreground)]\">Could not fetch news.</p>\n"
    else
      html += "      <ul class=\"space-y-2 mt-3\">\n"
      news.each do |story|
        link = story[:url] ? "<a href=\"#{story[:url]}\" target=\"_blank\" rel=\"noopener\" class=\"text-[var(--primary)] hover:underline\">#{story[:title]}</a>" : story[:title]
        html += "        <li class=\"text-sm\">#{link} <span class=\"text-[var(--muted-foreground)]\">(#{story[:score]} pts)</span></li>\n"
      end
      html += "      </ul>\n"
    end

    html += <<~HTML
          </div>
        </div>
    HTML

    html
  end

  def upsert_page(html)
    page = Ai::AiPage.find_by(slug: "daily-briefing")

    if page
      page.update!(content: html)
      page
    else
      Ai::AiPage.create!(
        title: "Daily Briefing",
        slug: "daily-briefing",
        content: html,
        status: "published"
      )
    end
  end

  def create_notification(page)
    Ai::Notification.create!(
      title: "Your morning briefing is ready",
      body: "Weather and top stories for today.",
      kind: "info",
      status: "unread"
    ).broadcast!
  end

  def reschedule_for_tomorrow
    hour = (Ai::Config.get("briefing_hour") || "7").to_i
    tomorrow = Time.now + 86400
    scheduled_time = Time.new(tomorrow.year, tomorrow.month, tomorrow.day, hour, 0, 0)

    Ai::ScheduledTask.create!(
      title: "Daily Briefing",
      description: "Run the daily briefing skill",
      scheduled_for: scheduled_time,
      skill_name: "daily_briefing",
      parameters: {}
    )
  end
end
