# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'rack/utils'

module Fang
  class ApplicationClient
    # A base API client with HTTP methods for building service integrations.
    #
    # Authorization Bearer token header included by default.
    # Override `authorization_header` to customize.
    #
    # Content Type is application/json by default.
    # Override `content_type` to change.
    #
    # Example:
    #
    #   class DigitalOceanClient < Fang::ApplicationClient
    #     BASE_URI = "https://api.digitalocean.com/v2"
    #
    #     def account
    #       get("/account").account
    #     rescue *NET_HTTP_ERRORS
    #       raise Error, "Unable to load your account"
    #     end
    #   end

    class Error < StandardError; end
    class MovedPermanently < Error; end
    class Forbidden < Error; end
    class Unauthorized < Error; end
    class BadRequest < Error; end
    class UnprocessableContent < Error; end
    class RateLimit < Error; end
    class NotFound < Error; end
    class InternalError < Error; end

    BASE_URI = "https://example.org"
    NET_HTTP_ERRORS = [
      Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED,
      EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
    ].freeze

    attr_reader :token

    def self.inherited(client)
      super
      response = client.const_set(:Response, Class.new(Response))
      response.const_set(:PARSER, Response::PARSER.dup)

      client.const_set(:Error, Class.new(Error))
      client.const_set(:MovedPermanently, Class.new(MovedPermanently))
      client.const_set(:Forbidden, Class.new(Forbidden))
      client.const_set(:Unauthorized, Class.new(Unauthorized))
      client.const_set(:BadRequest, Class.new(BadRequest))
      client.const_set(:UnprocessableContent, Class.new(UnprocessableContent))
      client.const_set(:RateLimit, Class.new(RateLimit))
      client.const_set(:NotFound, Class.new(NotFound))
      client.const_set(:InternalError, Class.new(InternalError))
    end

    def initialize(token: nil)
      @token = token
    end

    def default_headers
      {
        "Accept" => content_type,
        "Content-Type" => content_type
      }.merge(authorization_header)
    end

    def content_type = "application/json"

    def authorization_header
      return {} unless token
      { "Authorization" => "Bearer #{token}" }
    end

    def default_query_params = {}

    def with_pagination(path, headers: {}, query: nil)
      page_query = query&.dup || {}

      loop do
        next_page = yield get(path, headers: headers, query: page_query)

        case next_page
        when String
          path = next_page
        when Hash
          page_query.merge!(next_page)
        else
          break
        end
      end
    end

    def get(path, **) = make_request(klass: Net::HTTP::Get, path: path, **)
    def post(path, **) = make_request(klass: Net::HTTP::Post, path: path, **)
    def patch(path, **) = make_request(klass: Net::HTTP::Patch, path: path, **)
    def put(path, **) = make_request(klass: Net::HTTP::Put, path: path, **)
    def delete(path, **) = make_request(klass: Net::HTTP::Delete, path: path, **)

    def base_uri = self.class::BASE_URI

    def open_timeout = nil
    def read_timeout = nil
    def write_timeout = nil

    def make_request(klass:, path:, headers: {}, body: nil, query: nil, form_data: nil, http_options: {})
      raise ArgumentError, "Cannot pass both body and form_data" if body && form_data

      path = path.to_s
      uri = path.start_with?("http") ? URI(path) : URI("#{base_uri}#{path}")

      query_params = Rack::Utils.parse_query(uri.query).merge(default_query_params)

      case query
      when String then query_params.merge!(Rack::Utils.parse_query(query))
      when Hash then query_params.merge!(query)
      end

      uri.query = Rack::Utils.build_query(query_params) unless query_params.empty?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.is_a?(URI::HTTPS)

      http.open_timeout = http_options[:open_timeout] || open_timeout || http.open_timeout
      http.read_timeout = http_options[:read_timeout] || read_timeout || http.read_timeout
      http.write_timeout = http_options[:write_timeout] || write_timeout || http.write_timeout

      all_headers = default_headers.merge(headers)
      all_headers.delete("Content-Type") if klass == Net::HTTP::Get

      request = klass.new(uri.request_uri, all_headers)

      if body
        request.body = build_body(body)
      elsif form_data
        request.set_form(form_data, "application/x-www-form-urlencoded")
      end

      log_request(klass, uri, all_headers, body: body, form_data: form_data)
      raw_response = http.request(request)
      response = self.class::Response.new(raw_response)
      log_response(response)

      handle_response(response)
    end

    def handle_response(response)
      case response.code
      when "200", "201", "202", "203", "204"
        response
      when "301"
        raise self.class::MovedPermanently, response.body
      when "400"
        raise self.class::BadRequest, response.body
      when "401"
        raise self.class::Unauthorized, response.body
      when "403"
        raise self.class::Forbidden, response.body
      when "404"
        raise self.class::NotFound, response.body
      when "422"
        raise self.class::UnprocessableContent, response.body
      when "429"
        raise self.class::RateLimit, response.body
      when "500"
        raise self.class::InternalError, response.body
      else
        raise self.class::Error, "#{response.code} - #{response.body}"
      end
    end

    def build_body(body)
      case body
      when String then body
      else body.to_json
      end
    end

    private

    def log_request(klass, uri, headers, body: nil, form_data: nil)
      return unless Fang.env == "development"

      method = klass.name.split("::").last.upcase
      sanitized_headers = headers.transform_values { |v| v.to_s.start_with?("Bearer") ? "Bearer [FILTERED]" : v }

      lines = ["[#{self.class.name}] #{method} #{uri}"]
      lines << "  Headers: #{sanitized_headers.inspect}"
      lines << "  Body: #{body.inspect}" if body
      lines << "  Form data: #{form_data.inspect}" if form_data

      Fang.logger.debug(lines.join("\n"))
    end

    def log_response(response)
      return unless Fang.env == "development"

      body_preview = response.body.to_s[0, 500]

      lines = ["[#{self.class.name}] Response #{response.code}"]
      lines << "  Body: #{body_preview}"

      Fang.logger.debug(lines.join("\n"))
    end

    class Response
      PARSER = {
        "application/json" => ->(response) { JSON.parse(response.body, object_class: OpenStruct) },
        "application/xml" => ->(response) { Nokogiri::XML(response.body) }
      }
      FALLBACK_PARSER = ->(response) { response.body }

      attr_reader :original_response

      def initialize(original_response)
        @original_response = original_response
      end

      def code = original_response.code
      def body = original_response.body

      def headers
        @headers ||= original_response.each_header.to_h.transform_keys { |k| k.tr("-", "_").to_sym }
      end

      def link_header
        @link_header ||= (headers[:link]&.split(", ") || []).to_h do |link|
          rel = link[/rel="(.+)"/, 1].to_sym
          url = link[/<(.+)>/, 1]
          [rel, url]
        end
      end

      def content_type = headers[:content_type]&.split(";")&.first

      def parsed_body
        @parsed_body ||= self.class::PARSER.fetch(content_type, FALLBACK_PARSER).call(self)
      end

      def method_missing(method, *args, &block)
        parsed_body.respond_to?(method) ? parsed_body.send(method, *args, &block) : super
      end

      def respond_to_missing?(method, include_private = false)
        parsed_body.respond_to?(method, include_private) || super
      end
    end
  end
end
