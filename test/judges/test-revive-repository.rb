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

  def test_keeps_repository_blocked_for_legal_reasons_stale
    seed = Random.new_seed
    repo = Random.new(seed).rand(1..999_999)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: repo, where: 'github', stale: 'repository')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      "GET /repositories/#{repo}" => 451
    ).run do
      load_it('revive-repository', fb)
    end
    assert_equal(
      ['repository'], fb.pick(repository: repo)['stale'],
      "the repository ##{repo} blocked for legal reasons was revived, seed #{seed}"
    )
  end

  def test_revives_repository_after_blocked_one
    seed = Random.new_seed
    blocked = Random.new(seed).rand(1..999_999)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: blocked, where: 'github', stale: 'repository')
    fb.with(_id: 2, what: 'issue-was-opened', repository: blocked + 1, where: 'github', stale: 'repository')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      "GET /repositories/#{blocked}" => 451,
      "GET /repositories/#{blocked + 1}" => { id: blocked + 1, name: 'ёжик', full_name: 'foo/ёжик' }
    ).run do
      load_it('revive-repository', fb)
    end
    assert_nil(
      fb.pick(repository: blocked + 1)['stale'],
      "the repository ##{blocked + 1} after the blocked ##{blocked} was not revived, seed #{seed}"
    )
  end
end
