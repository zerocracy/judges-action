# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
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
  SimpleCov.minimum_coverage_by_file 25
  SimpleCov.start do
    add_filter 'vendor/'
    add_filter 'target/'
    track_files 'judges/**/*.rb'
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

require 'judges/options'
require 'loog'
require 'minitest/autorun'

class Minitest::Test
  def load_it(judge, fb, options = Judges::Options.new({ 'repositories' => 'foo/foo' }))
    $fb = fb
    $global = {}
    $local = {}
    $judge = judge
    $options = options
    $loog = ENV['RACK_RUN'] ? Loog::NULL : Loog::VERBOSE
    $start = Time.now
    load(File.join(__dir__, "../judges/#{judge}/#{judge}.rb"))
  end

  def stub_github(url, body:, method: :get, status: 200,
                  headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '1000' })
    stub_request(method, url).to_return(status:, body: body.to_json, headers:)
  end
end
