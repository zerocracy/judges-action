# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start

require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

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
