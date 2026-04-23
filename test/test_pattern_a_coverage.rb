# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'

class TestPatternACoverage < Minitest::Test
  PATTERN_A_RE = /^(\s*)rescue\s+Octokit::NotFound\s*,\s*Octokit::Deprecated\s*=>\s*e/
  FORBIDDEN_RE = /^\s*rescue\s+Octokit::Forbidden\s*=>\s*e/
  ANY_RESCUE_RE = /^\s*rescue\b/
  BLOCK_END_RE  = /^\s*end\b/

  def test_every_pattern_a_block_has_an_adjacent_forbidden_rescue
    root = File.expand_path('..', __dir__)
    paths = Dir[File.join(root, '{lib,judges}', '**', '*.rb')]
    refute_empty(paths, 'should find Ruby files under lib/ and judges/')
    offenders = []
    paths.each do |path|
      lines = File.readlines(path)
      lines.each_with_index do |line, idx|
        m = PATTERN_A_RE.match(line)
        next unless m
        indent = m[1].length
        status = :not_found
        ((idx + 1)...lines.size).each do |j|
          nxt = lines[j]
          next if nxt.strip.empty?
          ni = nxt[/\A\s*/].length
          next if ni > indent
          if nxt =~ FORBIDDEN_RE && ni == indent
            status = :found
            break
          elsif nxt =~ ANY_RESCUE_RE || nxt =~ BLOCK_END_RE
            break
          end
        end
        next if status == :found
        rel = path.sub("#{root}/", '')
        offenders << "#{rel}:#{idx + 1} — Pattern A rescue has no adjacent " \
                     "'rescue Octokit::Forbidden => e' in the same begin/rescue/end block"
      end
    end
    assert_empty(
      offenders,
      "Every Pattern A rescue must be immediately followed by a Forbidden rescue at the same indent:\n  " \
      "#{offenders.join("\n  ")}"
    )
  end
end
