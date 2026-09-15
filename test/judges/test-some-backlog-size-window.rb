# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../test__helper'

class TestSomeBacklogSizeWindow < Jp::Test
  def test_samples_every_day_of_the_window
    WebMock.disable_net_connect!
    rate_limit_up
    $options = Judges::Options.new({ 'repositories' => 'foo/foo', 'testing' => true })
    $global = {}
    $loog = Loog::NULL
    $fb = Factbase.new
    asked = []
    octo = Fbe.octo(loog: Loog::NULL, global: {}, options: $options)
    octo.define_singleton_method(:search_issues) do |query, _opts = {}|
      asked << query
      { total_count: 1, items: [] }
    end
    require_relative('../../judges/quality-of-service/some_backlog_size')
    f = Factbase.new.insert
    f.since = Time.parse('2025-05-01 00:00:00 UTC')
    f.when = Time.parse('2025-05-11 00:00:00 UTC')
    Fbe.stub(:octo, ->(*, **) { octo }) do
      some_backlog_size(f)
    end
    assert_equal(11, asked.size, 'every day of the window must be sampled, not the last seven')
  end
end
