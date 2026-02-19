# frozen_string_literal: true

require 'net/http'
require 'json'

module Fang
  module Widgets
    class WeatherWidget < BaseWidget
      widget_type 'weather'
      menu_label 'Add Weather'
      menu_icon "\u{2600}\u{FE0F}"

      def self.header_title = 'Weather'
      def self.header_color = '#38bdf8'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>'
      end

      def self.refreshable?      = true
      def self.refresh_interval   = 1800 # 30 minutes
      def self.default_metadata   = { 'city' => 'Zurich', 'country' => 'CH' }

      def render_content
        city = @metadata['city'] || 'Zurich'
        temp = @metadata['temp_c']
        desc = @metadata['description']

        unless temp
          return <<~HTML
            <div class="flex flex-col gap-2">
              <div class="font-semibold text-sm" style="color:var(--foreground)">#{city}</div>
              <div class="text-xs" style="color:var(--muted-foreground)">Loading weather data...</div>
            </div>
          HTML
        end

        feels = @metadata['feels_like_c']
        humidity = @metadata['humidity']
        wind = @metadata['wind_kmph']
        wind_dir = @metadata['wind_dir']

        <<~HTML
          <div class="flex flex-col gap-2">
            <div class="flex items-center justify-between">
              <div>
                <div class="font-semibold text-sm" style="color:var(--foreground)">#{city}</div>
                <div class="text-xs" style="color:var(--muted-foreground)">#{desc}</div>
              </div>
              <span class="text-2xl">\u{2600}\u{FE0F}</span>
            </div>
            <div class="flex items-baseline gap-1">
              <span class="text-3xl font-bold" style="color:var(--foreground)">#{temp}\u00B0C</span>
              <span class="text-xs" style="color:var(--muted-foreground)">Feels like #{feels}\u00B0</span>
            </div>
            <div class="grid grid-cols-3 gap-2 pt-1" style="border-top:1px solid var(--border)">
              <div class="text-center">
                <div class="text-xs" style="color:var(--muted-foreground)">Humidity</div>
                <div class="text-sm font-medium" style="color:var(--foreground)">#{humidity}%</div>
              </div>
              <div class="text-center">
                <div class="text-xs" style="color:var(--muted-foreground)">Wind</div>
                <div class="text-sm font-medium" style="color:var(--foreground)">#{wind} km/h</div>
              </div>
              <div class="text-center">
                <div class="text-xs" style="color:var(--muted-foreground)">Direction</div>
                <div class="text-sm font-medium" style="color:var(--foreground)">#{wind_dir}</div>
              </div>
            </div>
          </div>
        HTML
      end

      def refresh_data!
        city = @metadata['city'] || 'Zurich'
        uri = URI("https://wttr.in/#{URI.encode_www_form_component(city)}?format=j1")
        response = Net::HTTP.get(uri)
        data = JSON.parse(response)

        current = data['current_condition']&.first || {}
        new_meta = @metadata.merge(
          'temp_c' => current['temp_C'],
          'feels_like_c' => current['FeelsLikeC'],
          'humidity' => current['humidity'],
          'description' => current.dig('weatherDesc', 0, 'value'),
          'wind_kmph' => current['windspeedKmph'],
          'wind_dir' => current['winddir16Point']
        )

        if new_meta != @metadata
          @component.update!(metadata: new_meta, content: self.class.new(@component.tap { |c| c.metadata = new_meta }).render_content)
          @metadata = new_meta
          true
        else
          false
        end
      rescue => e
        Fang.logger.error "Weather widget refresh failed: #{e.message}"
        false
      end
    end
  end
end
