# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require 'octokit'
require_relative '../test__helper'

class TestEraseRepository < Jp::Test
  using SmartFactbase

  def test_erase_not_found_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repositories/1234', body: { id: 1234, name: 'foo', full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/1235', body: { id: 1235, name: 'bar', full_name: 'foo/bar' })
    stub_github('https://api.github.com/repositories/404123', body: '', status: 404)
    stub_github('https://api.github.com/repositories/404124', body: '', status: 404)
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 1234
    end
    fb.insert.then do |f|
      f._id = 2
      f.where = 'github'
      f.repository = 404_123
    end
    fb.insert.then do |f|
      f._id = 3
      f.where = 'github'
      f.repository = 1235
    end
    fb.insert.then do |f|
      f._id = 4
      f.where = 'github'
      f.repository = 404_124
    end
    fb.insert.then do |f|
      f._id = 5
      f.where = 'gitlab'
      f.repository = 404_123
    end
    fb.insert.then do |f|
      f._id = 6
      f.where = 'github'
    end
    fb.insert.then do |f|
      f._id = 7
      f.where = 'gitlab'
    end
    load_it('erase-repository', fb)
    assert_equal(5, fb.query('(exists repository)').each.to_a.size)
    assert_equal(2, fb.query('(exists stale)').each.to_a.size)
    assert_equal(2, fb.query('(absent repository)').each.to_a.size)
    assert_equal(4, fb.query('(and (eq where "github") (exists repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "github") (absent repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (exists repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (absent repository))').each.to_a.size)
  end

  def test_erase_deprecated_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repositories/410123', body: '', status: 410)
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 410_123
    end
    load_it('erase-repository', fb)
    assert_equal(1, fb.query('(exists stale)').each.to_a.size)
    assert_equal('repository', fb.query('(exists stale)').each.to_a.first.stale)
  end

  def test_forbidden_repository_is_not_erased
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repositories/403123', body: '', status: 403)
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 403_123
    end
    load_it('erase-repository', fb)
    assert_equal(0, fb.query('(exists stale)').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "github") (exists repository) (absent stale))').each.to_a.size)
  end

  def test_forbidden_repository_skipped_on_subsequent_facts
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github('https://api.github.com/repositories/403999', body: '', status: 403)
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 403_999
    end
    fb.insert.then do |f|
      f._id = 2
      f.where = 'github'
      f.repository = 403_999
    end
    load_it('erase-repository', fb)
    assert_requested(:get, 'https://api.github.com/repositories/403999', times: 1)
  end

  def test_dont_ask_about_the_quota_after_it_is_gone
    checks = 0
    octo = Object.new
    octo.define_singleton_method(:off_quota?) do |*|
      checks += 1
      true
    end
    octo.define_singleton_method(:print_trace!) { '' }
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', repository: 404_401, what: 'something-a')
      .with(_id: 2, where: 'github', repository: 404_402, what: 'something-b')
      .with(_id: 3, where: 'github', repository: 404_403, what: 'something-c')
    Fbe.stub(:octo, octo) do
      load_it('erase-repository', fb)
    end
    assert_equal(1, checks, 'An exhausted GitHub quota cannot be re-checked for every remaining fact')
  end

  def test_marks_a_repository_that_died_before_the_quota_was_gone
    checks = 0
    octo = Object.new
    octo.define_singleton_method(:off_quota?) do |*|
      checks += 1
      checks > 1
    end
    octo.define_singleton_method(:repository) { |_repo| raise(Octokit::NotFound) }
    octo.define_singleton_method(:print_trace!) { '' }
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', repository: 404_501, what: 'something-a')
      .with(_id: 2, where: 'github', repository: 404_502, what: 'something-b')
    Fbe.stub(:octo, octo) do
      load_it('erase-repository', fb)
    end
    assert_equal(
      1, fb.picks(repository: 404_501, stale: 'repository').count,
      'A repository confirmed missing before the quota ran out cannot stay unmarked'
    )
  end

  def test_dont_touch_a_repository_left_unchecked_by_the_lost_quota
    checks = 0
    octo = Object.new
    octo.define_singleton_method(:off_quota?) do |*|
      checks += 1
      checks > 1
    end
    octo.define_singleton_method(:repository) { |_repo| raise(Octokit::NotFound) }
    octo.define_singleton_method(:print_trace!) { '' }
    fb = Factbase.new
    fb.with(_id: 1, where: 'github', repository: 404_601, what: 'something-a')
      .with(_id: 2, where: 'github', repository: 404_602, what: 'something-b')
    Fbe.stub(:octo, octo) do
      load_it('erase-repository', fb)
    end
    assert(
      fb.none?(repository: 404_602, stale: 'repository'),
      'A repository nobody managed to ask GitHub about cannot be retired'
    )
  end
end
