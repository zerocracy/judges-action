# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/pull_request'
require_relative '../test__helper'

class TestPullRequestShape < Jp::Test
  def test_keeps_the_shape_when_the_repository_is_unknown
    $options = Judges::Options.new({})
    $global = {}
    $loog = Loog::NULL
    pr = { number: 7 }
    assert_equal(
      %i[comments comments_to_code comments_by_author comments_by_reviewers comments_appreciated comments_resolved],
      Jp.comments_info(pr).keys,
      'a pull with no repository must still answer with every comment property'
    )
    assert_equal(
      { succeeded_builds: 0, failed_builds: 0 },
      Jp.fetch_workflows(pr),
      'a pull with no repository must still answer with both build properties'
    )
  end
end
