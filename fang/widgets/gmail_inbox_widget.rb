# frozen_string_literal: true

module Fang
  module Widgets
    class GmailInboxWidget < BaseWidget
      widget_type 'gmail_inbox'
      menu_label 'Gmail Inbox'
      menu_icon "\u{1F4E7}"
      menu_category 'Communication'

      def self.refreshable?     = true
      def self.refresh_interval = 300
      def self.header_title     = 'Gmail Inbox'
      def self.header_color     = '#ea4335'

      def render_content
        unless Fang::Gmail.enabled?
          return %(<div class="p-4 text-center text-sm text-fang-muted-fg">Gmail not connected. Configure OAuth credentials to enable.</div>)
        end

        emails = fetch_emails
        return %(<div class="p-4 text-center text-sm text-fang-muted-fg">Inbox Zero</div>) if emails.empty?

        html = +%(<div class="space-y-2 p-3">)
        emails.each do |email|
          html << render_email_row(email)
        end
        html << %(</div>)
        html
      rescue => e
        Fang.logger.error "Gmail inbox widget error: #{e.message}"
        %(<div class="p-4 text-center text-sm text-fang-muted-fg">Unable to load emails</div>)
      end

      def refresh_data!
        new_content = render_content
        if new_content != @component.content
          @component.update!(content: new_content)
          true
        else
          false
        end
      end

      private

      def fetch_emails
        Fang::Gmail.search("is:unread", max_results: 5)
      rescue => e
        Fang.logger.error "Gmail fetch failed: #{e.message}"
        []
      end

      def render_email_row(email)
        from = h(truncate(email[:from].to_s, 30))
        subject = h(truncate(email[:subject].to_s, 50))
        snippet = h(truncate(email[:snippet].to_s, 60))
        date = email[:date].to_s

        html = +%(<div class="card p-2 space-y-1">)
        html << %(<div class="flex justify-between items-start gap-2">)
        html << %(<span class="text-xs font-semibold truncate" style="color:var(--foreground)">#{from}</span>)
        html << %(<span class="text-xs whitespace-nowrap" style="color:var(--muted-foreground)">#{h date}</span>)
        html << %(</div>)
        html << %(<div class="text-sm font-medium truncate">#{subject}</div>)
        html << %(<div class="text-xs truncate" style="color:var(--muted-foreground)">#{snippet}</div>)
        html << %(</div>)
        html
      end

      def truncate(str, len)
        str.length > len ? "#{str[0...len]}..." : str
      end
    end
  end
end
