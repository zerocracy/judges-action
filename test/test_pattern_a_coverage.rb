# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'

class TestPatternACoverage < Minitest::Test
  PATTERN_A_RE = /rescue\s+Octokit::NotFound\s*,\s*Octokit::Deprecated\s*=>\s*e/
  FORBIDDEN_RE = /rescue\s+Octokit::Forbidden\s*=>\s*e/

  def test_every_pattern_a_block_has_a_matching_forbidden_rescue
    root = File.expand_path('..', __dir__)
    paths = Dir[File.join(root, '{lib,judges}', '**', '*.rb')]
    refute_empty(paths, 'should find Ruby files under lib/ and judges/ — empty means the glob is broken')
    offenders = []
    paths.each do |path|
      content = File.read(path)
      found = content.scan(PATTERN_A_RE).size
      next if found.zero?
      caught = content.scan(FORBIDDEN_RE).size
      next if caught >= found
      rel = path.sub("#{root}/", '')
      offenders << "#{rel} — has #{found} Pattern A rescue(s) " \
                   "but only #{caught} matching 'rescue Octokit::Forbidden => e'"
    end
    assert_empty(
      offenders,
      "Every Pattern A rescue block must be paired with a 'rescue Octokit::Forbidden => e' in the same file:\n  " \
      "#{offenders.join("\n  ")}"
    )
  end
end
