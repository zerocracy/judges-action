# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestTotalContributorsCap < Jp::Test
  def test_reports_nothing_when_the_list_is_capped
    $judge = 'dimensions-of-terrain'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:repository) { |_repo| { size: 100 } }
    octo.define_singleton_method(:contributors) { |_repo| Array.new(500) { |i| { id: i + 1 } } }
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_contributors.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { total_contributors(nil) }
      end
    assert_empty(result)
  end

  def test_counts_a_list_below_the_cap
    $judge = 'dimensions-of-terrain'
    $loog = Loog::NULL
    $global = {}
    $options = Judges::Options.new({ 'repositories' => 'foo/foo' })
    octo = Object.new
    octo.define_singleton_method(:repository) { |_repo| { size: 100 } }
    octo.define_singleton_method(:contributors) { |_repo| Array.new(7) { |i| { id: i + 1 } } }
    load(File.join(__dir__, '../../judges/dimensions-of-terrain/total_contributors.rb'))
    result =
      Fbe.stub(:octo, octo) do
        Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) { total_contributors(nil) }
      end
    assert_equal({ total_contributors: 7 }, result)
  end
end
