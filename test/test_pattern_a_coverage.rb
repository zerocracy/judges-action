# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'

# Structural regression test for the "Pattern A rescue" uniformity invariant.
# Every line of the form `rescue Octokit::NotFound, Octokit::Deprecated` in
# lib/*.rb or judges/*/*.rb MUST also contain Octokit::Forbidden — otherwise a
# single 403 from GitHub can escape the rescue and crash the judge's iteration
# over a batch of items (see specs/002-wide-forbidden-rescue/spec.md).
class TestPatternACoverage < Minitest::Test
  PATTERN_A_RE = /rescue\s+Octokit::NotFound\s*,\s*Octokit::Deprecated/
  FORBIDDEN_RE = /Octokit::Forbidden/

  def test_every_pattern_a_block_also_catches_forbidden
    root = File.expand_path('..', __dir__)
    paths = Dir[File.join(root, '{lib,judges}', '**', '*.rb')]
    refute_empty(paths, 'should find Ruby files under lib/ and judges/ — empty means the glob is broken')
    offenders = []
    paths.each do |path|
      File.foreach(path).with_index(1) do |line, lineno|
        next unless line =~ PATTERN_A_RE
        next if line =~ FORBIDDEN_RE
        offenders << "#{path.sub("#{root}/", '')}:#{lineno}"
      end
    end
    assert_empty(
      offenders,
      "Pattern A rescue blocks must include Octokit::Forbidden. Offending site(s):\n  " \
      "#{offenders.join("\n  ")}"
    )
  end
end