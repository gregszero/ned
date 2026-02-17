# frozen_string_literal: true

require 'net/http'
require 'json'

module Ai
  module Tools
    class WebFetchTool < FastMcp::Tool
      tool_name 'web_fetch'
      description 'Fetch content from a URL. Returns the response body, status code, and content type. Supports JSON auto-parsing.'

      arguments do
        required(:url).filled(:string).description('The URL to fetch')
        optional(:method).filled(:string).description('HTTP method: get (default), post, put, patch, delete')
        optional(:headers).description('Additional HTTP headers as a JSON object')
        optional(:body).filled(:string).description('Request body for POST/PUT/PATCH requests')
      end

      def call(url:, method: 'get', headers: nil, body: nil)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 30

        request = build_request(method, uri, headers, body)
        response = http.request(request)

        result = {
          success: true,
          status: response.code.to_i,
          content_type: response['content-type'],
          body: response.body
        }

        if response['content-type']&.include?('application/json')
          result[:json] = JSON.parse(response.body)
        end

        result
      rescue => e
        Ai.logger.error "Web fetch failed: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def build_request(method, uri, headers, body)
        request_class = {
          'get' => Net::HTTP::Get,
          'post' => Net::HTTP::Post,
          'put' => Net::HTTP::Put,
          'patch' => Net::HTTP::Patch,
          'delete' => Net::HTTP::Delete
        }.fetch(method.downcase) { raise "Unsupported HTTP method: #{method}" }

        request = request_class.new(uri)
        request['User-Agent'] = 'Ned/1.0'

        if headers.is_a?(Hash)
          headers.each { |k, v| request[k] = v }
        end

        if body && %w[post put patch].include?(method.downcase)
          request.body = body
          request['Content-Type'] ||= 'application/json'
        end

        request
      end
    end
  end
end
