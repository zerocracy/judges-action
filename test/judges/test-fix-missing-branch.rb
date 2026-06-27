# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFixMissingBranch < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('fix-missing-branch/rescues-forbidden-on-issue-lookup') do
      load_it('fix-missing-branch', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    msg = '403 is transient — fact must NOT be marked stale; next cycle will retry the pull_request lookup'
    assert_nil(f['stale'], msg)
  end
end
