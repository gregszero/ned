# frozen_string_literal: true

require 'net/http'
require 'nokogiri'

module Fang
  module Widgets
    class WebsiteWidget < BaseWidget
      widget_type 'website'
      menu_label 'Add Website'
      menu_icon '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>'

      def self.refreshable?     = true
      def self.refresh_interval  = 3600 # 1 hour

      def self.header_title = 'Website'
      def self.header_color = '#60a5fa'
      def self.header_icon
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>'
      end

      def self.default_metadata
        { 'url' => '', 'mode' => 'snippet', 'title' => 'Website', 'description' => '', 'extraction_code' => '' }
      end

      def render_content
        url = @metadata['url']
        mode = @metadata['mode'] || 'snippet'

        # Empty state — no URL yet
        if url.nil? || url.empty?
          return <<~HTML
            <div class="flex flex-col gap-2 p-2" data-website-empty="true">
              <div class="text-xs" style="color:var(--muted-foreground)">Enter a URL to get started</div>
            </div>
          HTML
        end

        if mode == 'iframe'
          <<~HTML
            <div style="height:100%;min-height:300px">
              <iframe src="#{h url}" style="width:100%;height:100%;border:none;border-radius:0 0 var(--radius-lg) var(--radius-lg)" sandbox="allow-scripts allow-same-origin allow-forms allow-popups"></iframe>
            </div>
          HTML
        else
          # Snippet mode — show extracted content or loading state
          extracted = @metadata['extracted_content']
          if extracted && !extracted.empty?
            <<~HTML
              <div class="prose-bubble">#{extracted}</div>
              <div class="pt-2 mt-2" style="border-top:1px solid var(--border)">
                <a href="#{h url}" target="_blank" rel="noopener" class="text-xs" style="color:var(--muted-foreground)">#{h truncate_url(url)}</a>
              </div>
            HTML
          else
            <<~HTML
              <div class="flex flex-col gap-2 p-2">
                <div class="text-xs" style="color:var(--muted-foreground)">Fetching content...</div>
                <a href="#{h url}" target="_blank" rel="noopener" class="text-xs" style="color:var(--muted-foreground)">#{h truncate_url(url)}</a>
              </div>
            HTML
          end
        end
      end

      def refresh_data!
        url = @metadata['url']
        mode = @metadata['mode'] || 'snippet'
        return false if url.nil? || url.empty? || mode == 'iframe'

        extraction_code = @metadata['extraction_code']
        return false if extraction_code.nil? || extraction_code.empty?

        begin
          uri = URI(url)
          response = Net::HTTP.get_response(uri)
          html = response.body.force_encoding('UTF-8')

          # Execute extraction code with Nokogiri doc available
          doc = Nokogiri::HTML(html)
          ctx = Object.new
          ctx.define_singleton_method(:doc) { doc }
          ctx.define_singleton_method(:url) { url }
          extracted = ctx.instance_eval(extraction_code).to_s

          new_meta = @metadata.merge('extracted_content' => extracted)
          if new_meta != @metadata
            @component.update!(metadata: new_meta, content: self.class.new(@component.tap { |c| c.metadata = new_meta }).render_content)
            @metadata = new_meta
            true
          else
            false
          end
        rescue => e
          Fang.logger.error "Website widget refresh failed: #{e.message}"
          false
        end
      end

      private

      def truncate_url(url)
        url.length > 50 ? url[0..47] + '...' : url
      end
    end
  end
end
