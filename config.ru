# frozen_string_literal: true

require_relative 'ai/bootstrap'
require_relative 'web/app'

# Freeze the app for better performance
run Ai::Web::App.freeze.app
