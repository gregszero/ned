# frozen_string_literal: true

ENV['FANG_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

require 'bundler/setup'
require 'minitest/autorun'
require 'rack/test'
require 'ostruct'
require 'webmock/minitest'
require 'database_cleaner/active_record'

# Load framework
require_relative '../fang/bootstrap'

# Load MCP tools (auto-discovered at runtime, but we need them in tests)
Dir[File.join(Fang.root, 'fang/tools/**/*.rb')].sort.each { |f| require f }

# Run migrations on the test database
Fang::Database.migrate!

# Configure ActiveJob for synchronous test execution
ActiveJob::Base.queue_adapter = :inline

# Configure DatabaseCleaner — use truncation to clear seed data between tests
DatabaseCleaner.strategy = :truncation

# Clean seed data once at boot so tests start with an empty DB
DatabaseCleaner.clean

module Fang
  class TestCase < Minitest::Test
    def setup
      DatabaseCleaner.start
    end

    def teardown
      DatabaseCleaner.clean
    end
  end

  class ToolTestCase < TestCase
    def setup
      super
      # Silence TurboBroadcast so tool tests don't need SSE subscribers
      Fang::Web::TurboBroadcast.instance_variable_set(:@subscribers, Hash.new { |h, k| h[k] = [] })
    end
  end

  class RouteTestCase < TestCase
    include Rack::Test::Methods

    def app
      Fang::Web::App.app
    end
  end
end
