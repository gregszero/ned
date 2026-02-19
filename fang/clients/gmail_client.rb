# frozen_string_literal: true

module Fang
  module Clients
    class GmailClient < ApplicationClient
      BASE_URI = "https://gmail.googleapis.com"

      def authorization_header
        token = Fang::Gmail.access_token
        return {} unless token
        { "Authorization" => "Bearer #{token}" }
      end

      def list_messages(query: nil, max_results: 10)
        params = { maxResults: max_results }
        params[:q] = query if query
        get("/gmail/v1/users/me/messages", query: params)
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to list messages"
      end

      def get_message(id, format: "full")
        get("/gmail/v1/users/me/messages/#{id}", query: { format: format })
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to get message #{id}"
      end

      def send_message(raw:)
        post("/gmail/v1/users/me/messages/send", body: { raw: raw })
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to send message"
      end

      def create_draft(raw:)
        post("/gmail/v1/users/me/drafts", body: { message: { raw: raw } })
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to create draft"
      end

      def modify_message(id, add_labels: [], remove_labels: [])
        post("/gmail/v1/users/me/messages/#{id}/modify", body: {
          addLabelIds: add_labels,
          removeLabelIds: remove_labels
        })
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to modify message #{id}"
      end

      def delete_message(id)
        delete("/gmail/v1/users/me/messages/#{id}")
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to delete message #{id}"
      end

      def list_labels
        get("/gmail/v1/users/me/labels")
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to list labels"
      end
    end
  end
end
