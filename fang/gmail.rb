# frozen_string_literal: true

require 'base64'
require 'net/http'
require 'json'
require 'uri'

module Fang
  module Gmail
    OAUTH_AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth"
    OAUTH_TOKEN_URI = "https://oauth2.googleapis.com/token"
    REDIRECT_URI = "http://127.0.0.1:8484"
    SCOPES = "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.compose https://www.googleapis.com/auth/gmail.labels"

    class << self
      def enabled?
        ENV['GMAIL_CLIENT_ID'] && ENV['GMAIL_CLIENT_SECRET']
      end

      # --- OAuth ---

      def authorization_url
        params = URI.encode_www_form(
          client_id: ENV['GMAIL_CLIENT_ID'],
          redirect_uri: REDIRECT_URI,
          response_type: "code",
          scope: SCOPES,
          access_type: "offline",
          prompt: "consent"
        )
        "#{OAUTH_AUTH_URI}?#{params}"
      end

      def exchange_code!(code)
        response = token_request(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: REDIRECT_URI
        )

        Config.set('gmail.access_token', response['access_token'])
        Config.set('gmail.refresh_token', response['refresh_token']) if response['refresh_token']
        Config.set('gmail.token_expires_at', (Time.now + response['expires_in'].to_i).iso8601)

        Fang.logger.info "Gmail OAuth tokens stored successfully"
        true
      end

      def access_token
        token = Config.get('gmail.access_token')
        expires_at = Config.get('gmail.token_expires_at')

        if token && expires_at && Time.parse(expires_at) > Time.now + 60
          token
        else
          refresh_access_token!
        end
      end

      # --- Public API ---

      def search(query, max_results: 10)
        response = client.list_messages(query: query, max_results: max_results)
        messages = response.messages || []

        messages.map do |msg|
          full = client.get_message(msg.id, format: "metadata")
          headers = extract_headers(full)
          {
            id: msg.id,
            subject: headers[:subject],
            from: headers[:from],
            date: headers[:date],
            snippet: full.snippet,
            labels: full.labelIds || []
          }
        end
      end

      def read(message_id)
        msg = client.get_message(message_id, format: "full")
        headers = extract_headers(msg)
        {
          id: msg.id,
          subject: headers[:subject],
          from: headers[:from],
          to: headers[:to],
          date: headers[:date],
          body: extract_body(msg.payload),
          labels: msg.labelIds || []
        }
      end

      def send_email(to:, subject:, body:, html: false)
        raw = build_mime(to: to, subject: subject, body: body, html: html)
        response = client.send_message(raw: base64url(raw))
        { id: response.id, thread_id: response.threadId }
      end

      def draft(to:, subject:, body:)
        raw = build_mime(to: to, subject: subject, body: body, html: false)
        response = client.create_draft(raw: base64url(raw))
        { id: response.id, message_id: response.message&.id }
      end

      def modify(message_id, add_labels: [], remove_labels: [])
        client.modify_message(message_id, add_labels: add_labels, remove_labels: remove_labels)
        true
      end

      def delete(message_id)
        client.delete_message(message_id)
        true
      end

      def labels
        response = client.list_labels
        (response.labels || []).map do |label|
          { id: label.id, name: label.name, type: label.type }
        end
      end

      private

      def client
        @client ||= Clients::GmailClient.new
      end

      def refresh_access_token!
        refresh_token = Config.get('gmail.refresh_token')
        raise "Gmail not authenticated. Run ./openfang.rb gmail:auth" unless refresh_token

        response = token_request(
          grant_type: "refresh_token",
          refresh_token: refresh_token
        )

        Config.set('gmail.access_token', response['access_token'])
        Config.set('gmail.token_expires_at', (Time.now + response['expires_in'].to_i).iso8601)

        response['access_token']
      end

      def token_request(**params)
        uri = URI(OAUTH_TOKEN_URI)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request.set_form_data(
          params.merge(
            client_id: ENV['GMAIL_CLIENT_ID'],
            client_secret: ENV['GMAIL_CLIENT_SECRET']
          )
        )

        response = http.request(request)
        parsed = JSON.parse(response.body)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OAuth token request failed: #{parsed['error_description'] || parsed['error']}"
        end

        parsed
      end

      def extract_headers(msg)
        headers_list = msg.payload&.headers || []
        {}.tap do |h|
          headers_list.each do |header|
            case header.name.downcase
            when "subject" then h[:subject] = header.value
            when "from" then h[:from] = header.value
            when "to" then h[:to] = header.value
            when "date" then h[:date] = header.value
            end
          end
        end
      end

      def extract_body(payload)
        return "" unless payload

        # Direct body data
        if payload.body&.data
          return Base64.urlsafe_decode64(payload.body.data)
        end

        # Multipart — prefer text/plain, fall back to text/html
        parts = payload.parts || []
        text_part = parts.find { |p| p.mimeType == "text/plain" }
        html_part = parts.find { |p| p.mimeType == "text/html" }

        # Check nested multipart/alternative
        alt_part = parts.find { |p| p.mimeType == "multipart/alternative" }
        if alt_part
          sub_parts = alt_part.parts || []
          text_part ||= sub_parts.find { |p| p.mimeType == "text/plain" }
          html_part ||= sub_parts.find { |p| p.mimeType == "text/html" }
        end

        part = text_part || html_part
        return "" unless part&.body&.data

        Base64.urlsafe_decode64(part.body.data)
      end

      def build_mime(to:, subject:, body:, html: false)
        content_type = html ? "text/html" : "text/plain"
        [
          "To: #{to}",
          "Subject: #{subject}",
          "Content-Type: #{content_type}; charset=UTF-8",
          "MIME-Version: 1.0",
          "",
          body
        ].join("\r\n")
      end

      def base64url(str)
        Base64.urlsafe_encode64(str, padding: false)
      end
    end
  end
end
