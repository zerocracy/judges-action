# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestMilestoneWasSetStale < Jp::Test
  using SmartFactbase

  def test_marks_every_fact_of_a_gone_repository
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repositories/42',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'pull-was-merged', repository: 42, issue: 46, where: 'github')
    load_it('milestone-was-set', fb)
    fb.query('(exists repository)').each.to_a.each do |f|
      assert_equal(['repository'], f['stale'], 'every fact of a gone repository must be marked stale')
    end
  end
end
