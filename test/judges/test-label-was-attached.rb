# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestLabelWasAttached < Jp::Test
  using SmartFactbase

  def test_catches_label_event
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42/issues/42/timeline?per_page=100').to_return(
      body: [{ event: 'labeled', label: { name: 'bug' }, actor: { id: 42 }, created_at: Time.now }].to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    op = fb.insert
    op.where = 'github'
    op.what = 'issue-was-opened'
    op.repository = 42
    op.issue = 42
    load_it('label-was-attached', fb)
    load(File.join(__dir__, '../../judges/label-was-attached/label-was-attached.rb'))
    f = fb.query('(eq what "label-was-attached")').each.to_a.first
    refute_nil(f)
    assert_equal(42, f.who)
    assert_equal('bug', f.label)
  end

  def test_removes_lost_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 44, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/44').to_return(
      body: { id: 44, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/44/issues/44/timeline?per_page=100').to_return(
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    op = fb.insert
    op.what = 'issue-was-opened'
    op.repository = 44
    op.issue = 44
    op.where = 'github'
    load_it('label-was-attached', fb)
    f = fb.query('(eq what "issue-was-opened")').each.to_a
    assert_equal(0, f.count)
    f = fb.query('(eq issue 44)').each.to_a
    assert_equal(0, f.count)
  end

  def test_does_not_remove_labeled_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 44, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/44').to_return(
      body: { id: 44, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/44/issues/44/timeline?per_page=100').to_return(
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/44/issues/45/timeline?per_page=100').to_return(
      status: 200,
      body: [
        {
          event: 'labeled',
          label: { name: 'bug' },
          actor: { id: 45 },
          created_at: Time.now
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    f1 = fb.insert
    f1.what = 'issue-was-opened'
    f1.repository = 44
    f1.issue = 44
    f1.where = 'github'
    f2 = fb.insert
    f2.what = 'issue-was-opened'
    f2.repository = 44
    f2.issue = 45
    f2.where = 'github'
    load_it('label-was-attached', fb)
    facts = fb.query('(eq what "issue-was-opened")').each.to_a
    refute_empty(facts)
    f = facts.first
    assert_equal(45, f.issue)
    assert_equal('issue-was-opened', f.what)
    f = fb.query('(eq issue 44)').each.to_a
    assert_equal(0, f.count)
  end

  def test_does_not_remove_issue_from_other_repository
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 50, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/50').to_return(
      body: { id: 50, full_name: 'foo/foo' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/bar/bar').to_return(
      body: { id: 55, full_name: 'bar/bar' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/55').to_return(
      body: { id: 55, full_name: 'bar/bar' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/50/issues/46/timeline?per_page=100').to_return(
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/55/issues/46/timeline?per_page=100').to_return(
      body: [
        {
          event: 'labeled',
          label: { name: 'bug' },
          actor: { id: 46 },
          created_at: Time.now
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    op = fb.insert
    op.what = 'issue-was-opened'
    op.repository = 50
    op.issue = 46
    op.where = 'github'
    op = fb.insert
    op.what = 'issue-was-opened'
    op.repository = 55
    op.issue = 46
    op.where = 'github'
    load_it('label-was-attached', fb)
    f = fb.query('(and (eq what "issue-was-opened") (eq repository 50))').each.to_a
    assert_equal(0, f.count)
    f = fb.query('(and (eq issue 46) (eq repository 50))').each.to_a
    assert_equal(0, f.count)
    f = fb.query('(and (eq issue 46) (eq repository 55))').each.to_a
    assert_equal(1, f.count)
    assert_equal(46, f.first.issue)
    assert_equal(55, f.first.repository)
  end

  def test_catches_label_event_by_5_repeats
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stubs = []
    fb = Factbase.new
    fb.with(what: 'issue-was-opened', repository: 42, issue: 42, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 43, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 46, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 47, where: 'github')
      .with(what: 'issue-was-opened', repository: 42, issue: 48, where: 'github')
    begin
      stubs << stub_github(
        'https://api.github.com/repositories/42/issues/42/timeline?per_page=100',
        body: [{ event: 'labeled', label: { name: 'bug' }, actor: { id: 42 }, created_at: Time.now }]
      )
      [43, 44, 45, 46].each do |issue|
        stubs << stub_github("https://api.github.com/repositories/42/issues/#{issue}/timeline?per_page=100",
                             body: [])
      end
      load_it('label-was-attached', fb)
      assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 42, where: 'github',
                     label: 'bug', who: 42))
      assert(fb.one?(what: 'labels-were-scanned', repository: 42, latest: 46, where: 'github'))
    ensure
      stubs.each { WebMock.remove_request_stub(_1) }.clear
    end
    begin
      [47, 48].each do |issue|
        stubs << stub_github("https://api.github.com/repositories/42/issues/#{issue}/timeline?per_page=100",
                             body: [])
      end
      load_it('label-was-attached', fb)
      assert(fb.one?(what: 'labels-were-scanned', repository: 42, latest: 0, where: 'github'))
    ensure
      stubs.each { WebMock.remove_request_stub(_1) }.clear
    end
    begin
      [43, 44, 45, 46].each do |issue|
        stubs << stub_github("https://api.github.com/repositories/42/issues/#{issue}/timeline?per_page=100",
                             body: [])
      end
      stubs << stub_github(
        'https://api.github.com/repositories/42/issues/47/timeline?per_page=100',
        body: [{ event: 'labeled', label: { name: 'enhancement' }, actor: { id: 42 }, created_at: Time.now }]
      )
      load_it('label-was-attached', fb)
      assert(fb.one?(what: 'label-was-attached', repository: 42, issue: 47, where: 'github',
                     label: 'enhancement', who: 42))
      assert(fb.one?(what: 'labels-were-scanned', repository: 42, latest: 47, where: 'github'))
    ensure
      stubs.each { WebMock.remove_request_stub(_1) }.clear
    end
  end
end
