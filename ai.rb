#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'ai/bootstrap'
require_relative 'ai/cli'

Ai::CLI.start(ARGV)
