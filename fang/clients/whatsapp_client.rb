# frozen_string_literal: true

module Fang
  module Clients
    class WhatsAppClient < ApplicationClient
      BASE_URI = ENV.fetch('WHATSAPP_BRIDGE_URL', 'http://localhost:3001')

      def authorization_header = {}

      def send_message(phone:, message:)
        post("/send/message", body: { phone: phone, message: message })
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to send WhatsApp message"
      end

      def status
        get("/status")
      rescue *NET_HTTP_ERRORS
        raise Error, "WhatsApp bridge unavailable"
      end
    end
  end
end
