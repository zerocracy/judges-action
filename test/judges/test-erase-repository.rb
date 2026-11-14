# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative '../fake_github'
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

  def test_runs_without_fbe_consider
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'fbe'))
      File.write(File.join(dir, 'fbe/consider.rb'), "raise('fbe/consider is loaded by erase-repository')\n")
      script = <<~RUBY
        require 'factbase'
        require 'judges/options'
        require 'loog'
        $fb = Factbase.new
        $global = {}
        $options = Judges::Options.new({ 'testing' => true })
        $loog = Loog::NULL
        $judge = 'erase-repository'
        load(#{File.join(__dir__, '../../judges/erase-repository/erase-repository.rb').inspect})
      RUBY
      out, status = Open3.capture2e('ruby', '-I', dir, '-e', script)
      assert_predicate(status, :success?, "erase-repository does not run without fbe/consider: #{out}")
    end
  end

  def test_erases_repository_blocked_for_legal_reasons
    seed = Random.new_seed
    repo = Random.new(seed).rand(1..999_999)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: repo, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      "GET /repositories/#{repo}" => 451
    ).run do
      load_it('erase-repository', fb)
    end
    assert_equal(
      ['repository'], fb.pick(repository: repo)['stale'],
      "the repository ##{repo} blocked for legal reasons was not erased, seed #{seed}"
    )
  end

  def test_erases_missing_repository_after_blocked_one
    seed = Random.new_seed
    blocked = Random.new(seed).rand(1..999_999)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: blocked, where: 'github')
    fb.with(_id: 2, what: 'issue-was-opened', repository: blocked + 1, where: 'github')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { resources: { search: { remaining: 30, limit: 30 } }, rate: { remaining: 1000 } },
      "GET /repositories/#{blocked}" => 451,
      "GET /repositories/#{blocked + 1}" => 404
    ).run do
      load_it('erase-repository', fb)
    end
    assert_equal(
      ['repository'], fb.pick(repository: blocked + 1)['stale'],
      "the missing repository ##{blocked + 1} after the blocked ##{blocked} was not erased, seed #{seed}"
    )
  end
end
