# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'loog'
require_relative '../../lib/patches/fake_octokit'
require_relative '../test__helper'

class TestFakeOctokit < Jp::Test
  def test_lists_milestones_of_a_repository
    $global = {}
    $options = Judges::Options.new({ 'testing' => true })
    $loog = Loog::NULL
    assert_empty(
      Fbe.octo.list_milestones('foo/foo', state: 'all'),
      'The milestones stub cannot refuse the options that judges send with it'
    )
  end
end
