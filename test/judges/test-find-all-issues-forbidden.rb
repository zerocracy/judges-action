# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../test__helper'

class TestFindAllIssuesForbidden < Jp::Test
  def test_keeps_the_marker_after_a_forbidden_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 991 })
    stub_github('https://api.github.com/repositories/991', body: { full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/45',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.issue = 45
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    load_it('find-all-issues', fb)
    marker = fb.query("(eq what 'iterate')").each.to_a.first
    refute_nil(marker, 'the judge must leave its marker behind')
    assert_equal(45, marker.min_issue_was_found, 'a transient 403 cannot send the marker back to zero')
  end
end
