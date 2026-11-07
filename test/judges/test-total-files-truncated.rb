# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalFilesTruncated < Jp::Test
  def test_reports_nothing_when_every_tree_is_truncated
    $loog = Loog::Buffer.new
    assert_empty(counted({ 'foo/one' => nil, 'foo/two' => nil }))
    assert_includes($loog.to_s, 'is truncated, skipping it')
  end

  def test_keeps_the_count_of_trees_that_are_not_truncated
    $loog = Loog::Buffer.new
    assert_equal({ total_files: 2 }, counted({ 'foo/one' => nil, 'foo/two' => 2 }))
  end

  private

  def counted(blobs)
    $judge = 'dimensions-of-terrain'
    $global = {}
    $options = Judges::Options.new({ 'repositories' => blobs.keys.join(',') })
    octo = Object.new
    octo.define_singleton_method(:repository) { |_repo| { size: 100, default_branch: 'master' } }
    octo.define_singleton_method(:tree) do |repo, _branch, **|
      n = blobs[repo]
      n.nil? ? { truncated: true, tree: [] } : { truncated: false, tree: Array.new(n) { { type: 'blob' } } }
    end
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_files.rb'))
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| blobs.each_key { |r| b.call(r) } }) { total_files(nil) }
    end
  end
end
