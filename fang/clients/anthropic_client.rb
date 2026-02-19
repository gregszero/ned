# frozen_string_literal: true

module Fang
  module Clients
    class AnthropicClient < ApplicationClient
      BASE_URI = "https://api.anthropic.com/v1"

      def initialize(token: ENV['ANTHROPIC_API_KEY'])
        super(token: token)
      end

      def authorization_header
        return {} unless token
        { "x-api-key" => token }
      end

      def default_headers
        super.merge(
          "anthropic-version" => "2023-06-01"
        )
      end

      def create_message(model:, messages:, tools: nil, system: nil, max_tokens: 4096, betas: nil)
        body = {
          model: model,
          messages: messages,
          max_tokens: max_tokens
        }
        body[:tools] = tools if tools
        body[:system] = system if system

        headers = {}
        headers["anthropic-beta"] = betas.join(",") if betas&.any?

        post("/messages", body: body, headers: headers)
      rescue *NET_HTTP_ERRORS
        raise Error, "Unable to create message"
      end
    end
  end
end
