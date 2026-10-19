# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../fake_github'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_pull_hoc_size'

class TestSomePullHocSize < Jp::Test
  def test_records_zero_when_the_pull_has_no_changed_files
    fact = Factbase.new.insert
    fact.since = Time.parse('2025-01-01 00:00:00 UTC')
    fact.when = Time.parse('2025-02-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    found = { items: [{ id: 1, number: 10 }] }
    result =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/foo/pulls/10' => { number: 10, additions: 5, deletions: 3 }
      ).run { Jp.stub(:qosearch, found) { some_pull_hoc_size(fact) } }
    assert_equal([8], result[:some_pull_hoc_size])
    assert_equal([0], result[:some_pull_files_size])
  end
end
