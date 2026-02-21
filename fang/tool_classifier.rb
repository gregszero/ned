# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Fang
  module ToolClassifier
    GROUPS = %w[gmail canvas data documents automation system].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You classify user messages for an AI assistant. Return ONLY a comma-separated list of needed tool groups from: #{GROUPS.join(', ')}.
      Return 'none' if only basic tools are needed. Be conservative — only include groups clearly needed.

      Groups:
      - gmail: email reading, sending, searching, drafting, labels
      - canvas: pages, dashboards, widgets, charts, components, UI building
      - data: data tables, records, CRUD on structured data
      - documents: file upload, parsing, document creation
      - automation: triggers, workflows, heartbeats, approvals, pipelines
      - system: python code, browser automation, computer use
    PROMPT

    def self.classify(message, conversation: nil)
      context = build_context(message, conversation)

      api_key = ENV['ANTHROPIC_API_KEY']
      return nil unless api_key # no filtering if no API key

      uri = URI('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = 5

      body = {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 50,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: context }]
      }

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = api_key
      request['anthropic-version'] = '2023-06-01'
      request.body = JSON.generate(body)

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      text = data.dig('content', 0, 'text').to_s.strip.downcase

      return [:core] if text == 'none' || text.empty?

      groups = text.split(',').map(&:strip) & GROUPS
      [:core] + groups.map(&:to_sym)
    rescue => e
      Fang.logger.warn "Tool classification failed: #{e.message}, loading all tools"
      nil # nil = no filtering
    end

    def self.groups_string(groups)
      groups&.map(&:to_s)&.join(',')
    end

    # General-purpose Haiku call for cheap LLM tasks (summarization, classification, etc.)
    def self.call_haiku(prompt, system: nil, max_tokens: 1024)
      api_key = ENV['ANTHROPIC_API_KEY']
      return nil unless api_key

      uri = URI('https://api.anthropic.com/v1/messages')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15

      body = {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: max_tokens,
        messages: [{ role: 'user', content: prompt }]
      }
      body[:system] = system if system

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = api_key
      request['anthropic-version'] = '2023-06-01'
      request.body = JSON.generate(body)

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data.dig('content', 0, 'text').to_s.strip.presence
    rescue => e
      Fang.logger.warn "Haiku call failed: #{e.message}"
      nil
    end

    private_class_method def self.build_context(message, conversation)
      if conversation && conversation.messages.count > 1
        recent = conversation.messages.order(created_at: :desc).limit(3).map do |m|
          content = m.content.to_s
          truncated = content.length > 100 ? content[0..100] + '...' : content
          "#{m.role}: #{truncated}"
        end.reverse.join("\n")
        "Recent conversation:\n#{recent}\n\nNew message: #{message}"
      else
        message
      end
    end
  end
end
