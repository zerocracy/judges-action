# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'simplecov'
require 'simplecov-cobertura'
unless SimpleCov.running || ARGV.include?('--no-cov')
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
  SimpleCov.minimum_coverage 80
  SimpleCov.minimum_coverage_by_file 10
  SimpleCov.start do
    add_filter 'vendor/'
    add_filter 'target/'
    add_filter 'test/smart_factbase.rb'
    track_files 'judges/**/*.rb'
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
# Minitest.load :minitest_reporter

require 'judges/options'
require 'loog'
require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../lib/jp'
require_relative 'smart_factbase'

# Parent class for all tests.
class Jp::Test < Minitest::Test
  def rate_limit_up
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      body: { rate: { remaining: 1000, limit: 1000 } }.to_json,
      headers: { 'X-RateLimit-Remaining' => '999' }
    )
  end

  def load_it(judge, fb, options = Judges::Options.new({ 'repositories' => 'foo/foo' }), loog: nil)
    $fb = fb
    $global = {}
    $local = {}
    $judge = judge
    $options = options
    $loog = loog || (ENV['RACK_RUN'] ? Loog::NULL : Loog::VERBOSE)
    $epoch = Time.now
    $kickoff = Time.now
    load(File.join(__dir__, "../judges/#{judge}/#{judge}.rb"))
  end

  def stub_github(
    url, body:, method: :get, status: 200,
    headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '999' }
  )
    stub_request(method, url).to_return(status:, body: body.to_json, headers:)
  end
end
