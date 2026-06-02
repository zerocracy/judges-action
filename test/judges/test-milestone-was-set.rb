# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestMilestoneWasSet < Jp::Test
  using SmartFactbase

  def test_creates_facts_for_milestones
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      body: [
        {
          number: 1,
          title: 'v1.0',
          description: 'First release',
          state: 'open',
          created_at: '2024-01-15T10:00:00Z',
          due_on: '2024-03-15T10:00:00Z',
          creator: { id: 888, login: 'yegor256' }
        },
        {
          number: 2,
          title: 'v2.0',
          description: 'Second release',
          state: 'open',
          created_at: '2024-06-01T08:00:00Z',
          due_on: nil,
          creator: { id: 999, login: 'other' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    assert(fb.one?(what: 'milestone-was-set', milestone: 1))
    assert(fb.one?(what: 'milestone-was-set', milestone: 2))
    fb.query("(eq what 'milestone-was-set')").each do |f|
      case f.milestone
      when 1
        assert_equal(888, f.who)
        assert_equal(Time.parse('2024-01-15T10:00:00Z'), f.when)
        assert_equal(Time.parse('2024-03-15T10:00:00Z'), f.deadline)
      when 2
        assert_equal(999, f.who)
        assert_equal(Time.parse('2024-06-01T08:00:00Z'), f.when)
        assert_nil(f['deadline'])
      end
    end
  end

  def test_empty_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all', body: [])
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    assert_empty(fb.query("(eq what 'milestone-was-set')").each.to_a)
  end

  def test_skips_milestones_already_in_factbase
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      body: [
        {
          number: 1,
          title: 'v1.0',
          state: 'open',
          created_at: '2024-01-15T10:00:00Z',
          due_on: nil,
          creator: { id: 888, login: 'yegor256' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(_id: 2, what: 'milestone-was-set', repository: 42, milestone: 1, where: 'github')
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.query("(eq what 'milestone-was-set')").each.to_a.size)
  end

  def test_rescues_not_found_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      status: 404,
      body: { message: 'Not Found' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    assert_empty(fb.query("(eq what 'milestone-was-set')").each.to_a)
  end

  def test_rescues_deprecated_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      status: 410,
      body: { message: 'Gone' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    assert_empty(fb.query("(eq what 'milestone-was-set')").each.to_a)
  end

  def test_rescues_forbidden_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('milestone-was-set', fb)
    assert_empty(fb.query("(eq what 'milestone-was-set')").each.to_a)
  end
end
