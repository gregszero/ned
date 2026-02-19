#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'fang/bootstrap'
require_relative 'fang/cli'

Fang::CLI.start(ARGV)
