# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestMilestoneWasSet < Jp::Test
  using SmartFactbase

  def test_creates_milestone_fact
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 200,
      body: [
        {
          number: 1,
          title: 'v1.0',
          description: 'First release',
          due_on: '2025-06-01T00:00:00Z',
          created_at: '2025-01-15T10:00:00Z',
          creator: { id: 526_301, login: 'yegor256' }
        }
      ].to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size)
    f = fb.pick(what: 'milestone-was-set')
    refute_nil(f)
    assert_equal(1, f.milestone)
    assert_equal(42, f.repository)
    assert_equal('github', f.where)
    assert_equal(Time.parse('2025-01-15T10:00:00Z'), f.when)
    assert_equal(Time.parse('2025-06-01T00:00:00Z'), f.deadline)
    assert_equal(526_301, f.who)
  end

  def test_handles_empty_milestones
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(0, fb.all.size)
  end

  def test_deduplicates_milestones
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 200,
      body: [
        {
          number: 1,
          title: 'v1.0',
          due_on: '2025-06-01T00:00:00Z',
          created_at: '2025-01-15T10:00:00Z',
          creator: { id: 526_301, login: 'yegor256' }
        }
      ].to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size)
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size, 'must not duplicate on second run')
  end

  def test_handles_milestone_without_due_date
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 200,
      body: [
        {
          number: 2,
          title: 'Backlog',
          due_on: nil,
          created_at: '2025-02-01T08:00:00Z',
          creator: { id: 526_301, login: 'yegor256' }
        }
      ].to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(1, fb.all.size)
    f = fb.pick(what: 'milestone-was-set')
    refute_nil(f)
    assert_nil(f['deadline'], 'deadline should be nil when due_on is nil')
  end

  def test_rescues_forbidden_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 403,
      body: { message: 'Resource not accessible by integration' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(0, fb.all.size, '403 is transient — no facts created, judge continues')
  end

  def test_rescues_not_found_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 404,
      body: { message: 'Not Found' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(0, fb.all.size, '404 — no facts created, judge continues')
  end

  def test_rescues_deprecated_on_milestones_list
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/milestones?per_page=100&state=all').to_return(
      status: 410,
      body: { message: 'Gone' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    fb = Factbase.new
    load_it('milestone-was-set', fb)
    assert_equal(0, fb.all.size, '410 Gone — no facts created, judge continues')
  end
end
