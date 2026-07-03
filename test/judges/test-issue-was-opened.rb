# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestIssueWasOpened < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-closed', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('issue-was-opened/rescues-forbidden-on-issue-lookup') do
      load_it('issue-was-opened', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale; next cycle will retry the lookup')
  end
end
