# frozen_string_literal: true

require 'httparty'
require 'openssl'

module Fang
  module WhatsApp
    GOWA_BASE_URL = ENV.fetch('GOWA_URL', 'http://whatsapp:3000')

    class << self
      def enabled?
        ENV['WHATSAPP_ENABLED'] == 'true'
      end

      def handle_inbound(payload)
        jid = payload.dig('message', 'from') || payload.dig('from')
        return unless jid

        # Ignore group messages
        return if jid.end_with?('@g.us')

        text = extract_text(payload)
        return if text.nil? || text.strip.empty?

        phone = jid_to_phone(jid)
        message_id = payload.dig('message', 'id') || payload.dig('id')

        # Find or create conversation for this phone number
        conversation = find_or_create_conversation(phone, jid)

        # Create user message
        message = conversation.add_message(
          role: 'user',
          content: text,
          metadata: {
            source: 'whatsapp',
            whatsapp_from: jid,
            whatsapp_message_id: message_id
          }
        )

        # Route through MessageRouter
        MessageRouter.route(message, source: 'whatsapp')
      end

      def send_message(phone:, content:)
        response = HTTParty.post(
          "#{GOWA_BASE_URL}/send/message",
          headers: { 'Content-Type' => 'application/json' },
          body: {
            phone: phone,
            message: content
          }.to_json,
          timeout: 30
        )

        unless response.success?
          Fang.logger.error "WhatsApp send failed (#{response.code}): #{response.body}"
        end

        response
      end

      def verify_signature(raw_body, signature_header)
        secret = ENV['WHATSAPP_WEBHOOK_SECRET']
        return true if secret.nil? || secret.empty?
        return false if signature_header.nil? || signature_header.empty?

        expected = OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)
        Rack::Utils.secure_compare(expected, signature_header)
      end

      private

      def jid_to_phone(jid)
        jid.to_s.gsub(/@s\.whatsapp\.net$/, '')
      end

      def extract_text(payload)
        # GOWA webhook payload can have text in different locations
        payload.dig('message', 'text') ||
          payload.dig('message', 'conversation') ||
          payload.dig('message', 'extendedTextMessage', 'text') ||
          payload.dig('text')
      end

      def find_or_create_conversation(phone, jid)
        # Look for existing conversation with this phone number in context
        conversation = Conversation
          .where(source: 'whatsapp')
          .where("context->>'whatsapp_phone' = ?", phone)
          .order(last_message_at: :desc)
          .first

        return conversation if conversation

        Conversation.create!(
          title: "WhatsApp: #{phone}",
          source: 'whatsapp',
          context: {
            whatsapp_phone: phone,
            whatsapp_jid: jid
          }
        )
      end
    end
  end
end
