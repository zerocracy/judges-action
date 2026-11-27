# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../fake_github'
require_relative '../test__helper'

class TestReviveRepository < Jp::Test
  using SmartFactbase

  def test_revives_repository_that_answers_again
    seed = Random.new_seed
    repo = Random.new(seed).rand(1..999_999)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: repo, where: 'github', stale: 'repository')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      "GET /repositories/#{repo}" => { id: repo, name: 'żółw', full_name: 'foo/żółw' }
    ).run do
      load_it('revive-repository', fb)
    end
    assert_nil(
      fb.pick(repository: repo)['stale'],
      "the repository ##{repo} stayed stale although GitHub answered it, seed #{seed}"
    )
  end

  def test_keeps_repository_stale_after_a_server_error
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, where: 'github', stale: 'repository')
      .with(_id: 2, what: 'issue-was-opened', repository: 43, where: 'github', stale: 'repository')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      'GET /repositories/42' => [502, { message: 'Bad Gateway' }],
      'GET /repositories/43' => { id: 43, name: 'bar', full_name: 'foo/bar' }
    ).run do
      load_it('revive-repository', fb)
    end
    assert_equal('repository', fb.pick(repository: 42).stale, 'a 502 must not revive the repository')
    assert_nil(fb.pick(repository: 43)['stale'], 'a 502 on one repository must not stop the judge')
  end
end
