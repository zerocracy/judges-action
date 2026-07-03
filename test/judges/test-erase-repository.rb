# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestEraseRepository < Jp::Test
  def test_erase_not_found_repository
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
    rate_limit_up
    VCR.use_cassette('erase-repository/erase-not-found-repository') do
      load_it('erase-repository', fb)
    end
    assert_equal(5, fb.query('(exists repository)').each.to_a.size)
    assert_equal(2, fb.query('(exists stale)').each.to_a.size)
    assert_equal(2, fb.query('(absent repository)').each.to_a.size)
    assert_equal(4, fb.query('(and (eq where "github") (exists repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "github") (absent repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (exists repository))').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "gitlab") (absent repository))').each.to_a.size)
  end

  def test_erase_deprecated_repository
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 410_123
    end
    rate_limit_up
    VCR.use_cassette('erase-repository/erase-deprecated-repository') do
      load_it('erase-repository', fb)
    end
    assert_equal(1, fb.query('(exists stale)').each.to_a.size)
    assert_equal('repository', fb.query('(exists stale)').each.to_a.first.stale)
  end

  def test_forbidden_repository_is_not_erased
    fb = Factbase.new
    fb.insert.then do |f|
      f._id = 1
      f.where = 'github'
      f.repository = 403_123
    end
    rate_limit_up
    VCR.use_cassette('erase-repository/forbidden-repository-is-not-erased') do
      load_it('erase-repository', fb)
    end
    assert_equal(0, fb.query('(exists stale)').each.to_a.size)
    assert_equal(1, fb.query('(and (eq where "github") (exists repository) (absent stale))').each.to_a.size)
  end
end
