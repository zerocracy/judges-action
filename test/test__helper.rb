# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'minitest/reporters'
require 'loog'

# Use verbose logging when running tests directly, silent when via rake
if ENV['RAKE_RUN']
  Loog::VERBOSE
else
  Loog::NULL
end

Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]