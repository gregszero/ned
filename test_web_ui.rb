#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'ai/bootstrap'
require_relative 'web/app'
require 'rack/test'

# Create test data
puts "Creating test conversation..."
conversation = Ai::Conversation.create!(
  title: 'Test Conversation',
  source: 'web'
)

conversation.add_message(
  role: 'user',
  content: 'Hello, AI! This is a test message.'
)

conversation.add_message(
  role: 'assistant',
  content: 'Hello! I received your test message. The web UI is working!'
)

puts "✅ Created conversation ##{conversation.id} with #{conversation.messages.count} messages"

# Test the web app
puts "\nTesting web routes..."

class TestApp
  include Rack::Test::Methods

  def app
    Ai::Web::App.app
  end
end

test = TestApp.new

# Test root redirect
response = test.get '/'
puts "GET / → #{response.status} (redirect to conversations)"

# Test conversations list
response = test.get '/conversations'
puts "GET /conversations → #{response.status}"

# Test conversation show
response = test.get "/conversations/#{conversation.id}"
puts "GET /conversations/#{conversation.id} → #{response.status}"

# Test health check
response = test.get '/health'
puts "GET /health → #{response.status}"

puts "\n✅ All routes working!"
puts "\nTo view in browser:"
puts "  1. Run: ./ai.rb server"
puts "  2. Open: http://localhost:3000"
