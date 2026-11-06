# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../fake_github'
require_relative '../test__helper'

require_relative '../../judges/quality-of-service/some_release_hoc_size'

class TestSomeReleaseHocSize < Jp::Test
  def test_dont_measure_hoc_when_compare_cuts_the_files
    seed = Random.new_seed
    random = Random.new(seed)
    fact = Factbase.new.insert
    fact.since = Time.parse('2024-08-01 00:00:00 UTC')
    fact.when = Time.parse('2024-09-01 00:00:00 UTC')
    $global = {}
    $loog = Loog::NULL
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    sizes =
      Jp::FakeGithub.new(
        'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
        'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
        'GET /repos/foo/foo/releases?per_page=100' => [
          200,
          [
            { id: 2, tag_name: '2.0.0', published_at: '2024-08-20T00:00:00Z' },
            { id: 1, tag_name: '1.0.0', published_at: '2024-07-20T00:00:00Z' }
          ]
        ],
        'GET /repos/foo/foo/compare/1.0.0...2.0.0?per_page=100' => {
          total_commits: 3, commits: [],
          files: Array.new(300) { |i| { filename: "ф#{i}.rb", changes: random.rand(1..500) } }
        }
      ).run { some_release_hoc_size(fact) }
    assert_empty(sizes[:some_release_hoc_size], "hoc is taken from a cut list of files, seed #{seed}")
  end
end
