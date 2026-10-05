# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalFilesTruncated < Jp::Test
  def test_says_that_the_whole_total_is_dropped
    $judge = 'dimensions-of-terrain'
    $loog = Loog::Buffer.new
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/one,foo/two' })
    octo = Object.new
    octo.define_singleton_method(:repository) { |_repo| { size: 100, default_branch: 'master' } }
    octo.define_singleton_method(:tree) { |_repo, _branch, **| { truncated: true, tree: [] } }
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_files.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| %w[foo/one foo/two].each { |r| b.call(r) } }) { total_files(nil) }
      end
    assert_empty(result)
    assert_includes($loog.to_s, 'not reported')
  end
end
