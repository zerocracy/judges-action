# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'judges/options'
require 'loog'
require_relative '../../lib/patches/unmask_repos'
require_relative '../test__helper'

class TestUnmaskReposTransient < Jp::Test
  def test_survives_a_server_error_while_checking_archived
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/sick', status: 500, body: { message: 'Server Error' })
    stub_github('https://api.github.com/repos/foo/here', body: { full_name: 'foo/here', archived: false })
    $loog = Loog::NULL
    assert_equal(
      %w[foo/here foo/sick],
      Fbe.unmask_repos(
        options: Judges::Options.new({ 'repositories' => 'foo/sick,foo/here' }), global: {}, loog: Loog::NULL
      ).sort,
      'one server error cannot take down the whole expansion'
    )
  end
end
