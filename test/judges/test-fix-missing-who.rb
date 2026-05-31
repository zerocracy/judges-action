# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestFixMissingWho < Jp::Test
  using SmartFactbase

  def test_rescues_forbidden_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', repository: 42, issue: 44, where: 'github')
    VCR.use_cassette('fix-missing-who/rescues-forbidden-on-issue-lookup') do
      load_it('fix-missing-who', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale; next cycle will retry the issue lookup')
    assert_nil(f['who'], 'who must remain absent so the next cycle re-runs the lookup')
  end

  def test_rescues_deprecated_on_issue_lookup
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 55, where: 'github')
    VCR.use_cassette('fix-missing-who/rescues-deprecated-on-issue-lookup') do
      load_it('fix-missing-who', fb)
    end
    f = fb.query('(eq issue 55)').each.first
    refute_nil(f)
    assert_equal('issue', f['stale'].first, '410 is permanent — fact must be marked stale via Jp.issue_was_lost')
  end
end
