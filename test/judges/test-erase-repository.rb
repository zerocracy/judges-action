# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestEraseRepository < Jp::Test
  def test_erase_not_found_repository
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/rate_limit').to_return(
      { body: '{"rate":{"remaining":222}}', headers: { 'X-RateLimit-Remaining' => '222' } }
    )
    stub_github(
      'https://api.github.com/repositories/1234',
      body: { id: 1234, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/1235',
      body: { id: 1235, name: 'bar', full_name: 'foo/bar' }
    )
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
end
