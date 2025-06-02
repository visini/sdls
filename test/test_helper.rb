# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
require "minitest/mock"
require "stringio"
require_relative "../lib/sdls"

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "sdls"
