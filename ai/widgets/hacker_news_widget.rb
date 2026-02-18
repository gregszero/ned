# frozen_string_literal: true

require 'net/http'
require 'json'

module Ai
  module Widgets
    class HackerNewsWidget < BaseWidget
      widget_type 'hacker_news'
      menu_label 'Add HN Feed'
      menu_icon "\u{1F4F0}"

      def self.refreshable?      = true
      def self.refresh_interval   = 3600 # 1 hour
      def self.default_metadata   = { 'count' => 5 }

      def render_content
        stories = @metadata['stories']
        count = @metadata['count'] || 5

        unless stories
          return <<~HTML
            <div class="flex flex-col gap-2">
              <div class="font-semibold text-sm" style="color:var(--foreground)">Hacker News</div>
              <div class="text-xs" style="color:var(--muted-foreground)">Loading top stories...</div>
            </div>
          HTML
        end

        items = stories.first(count).map do |s|
          link = s['url'] ? %(<a href="#{s['url']}" target="_blank" rel="noopener" class="text-[var(--primary)] hover:underline">#{s['title']}</a>) : s['title']
          %(<li class="text-sm">#{link} <span class="text-[var(--muted-foreground)]">(#{s['score']} pts)</span></li>)
        end.join("\n")

        <<~HTML
          <div class="flex flex-col gap-2">
            <div class="font-semibold text-sm" style="color:var(--foreground)">Hacker News</div>
            <ul class="space-y-2">
              #{items}
            </ul>
          </div>
        HTML
      end

      def refresh_data!
        count = @metadata['count'] || 5
        uri = URI('https://hacker-news.firebaseio.com/v0/topstories.json')
        response = Net::HTTP.get(uri)
        story_ids = JSON.parse(response).first(count)

        stories = story_ids.map do |id|
          story_uri = URI("https://hacker-news.firebaseio.com/v0/item/#{id}.json")
          story_data = JSON.parse(Net::HTTP.get(story_uri))
          {
            'title' => story_data['title'],
            'url' => story_data['url'],
            'score' => story_data['score']
          }
        end

        new_meta = @metadata.merge('stories' => stories)
        if new_meta != @metadata
          @component.update!(metadata: new_meta, content: self.class.new(@component.tap { |c| c.metadata = new_meta }).render_content)
          @metadata = new_meta
          true
        else
          false
        end
      rescue => e
        Ai.logger.error "HN widget refresh failed: #{e.message}"
        false
      end
    end
  end
end
