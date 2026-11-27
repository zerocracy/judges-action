# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestFindAllIssuesForbidden < Jp::Test
  def test_keeps_the_marker_after_a_forbidden_issue
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.issue = 45
      f.repository = 991
      f.what = 'issue-was-opened'
      f.where = 'github'
    end
    Jp::FakeGithub.new(
      'GET /rate_limit' => {
        resources: { search: { remaining: 30, limit: 30 } },
        rate: { remaining: 1000, limit: 1000 }
      },
      'GET /repos/foo/foo' => { id: 991 },
      'GET /repositories/991' => { full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/45' => [403, { message: 'Resource not accessible by integration' }]
    ).run do
      load_it('find-all-issues', fb)
    end
    marker = fb.query("(eq what 'iterate')").each.to_a.first
    refute_nil(marker, 'the judge must leave its marker behind')
    assert_equal(45, marker.min_issue_was_found, 'a transient 403 cannot send the marker back to zero')
  end
end
