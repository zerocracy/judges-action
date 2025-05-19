# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'factbase'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestTypeWasAttached < Jp::Test
  def test_catches_type_event
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repositories/42/issues/42/timeline?per_page=100',
      body: [
        {
          event: 'issue_type_added', node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
          actor: { id: 42 }, created_at: Time.now
        },
        {
          event: 'issue_type_changed', node_id: 'ITCE_examplevq862Ga8lzwAAAAQZbq9S',
          actor: { id: 42 }, created_at: Time.now
        },
        {
          event: 'issue_type_changed', node_id: 'ITCE_examplevq862Ga8lzwAAAAQZbq9S',
          actor: { id: 42 }, created_at: Time.now
        },
        {
          event: 'issue_type_changed', node_id: 'ITCE_wrongID2Ga8lzwAAAAQZbq9S',
          actor: { id: 42 }, created_at: Time.now
        },
        {
          event: 'issue_type_removed', node_id: 'ITRE_examplevq862Ga8lzwAAAAQcqceV',
          actor: { id: 42 }, created_at: Time.now
        }
      ]
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 42
      f.issue = 42
    end
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('type-was-attached', fb)
      fs = fb.query('(eq what "type-was-attached")').each.to_a
      assert_equal(2, fs.count)
      assert_equal(526_301, fs[0].who)
      assert_equal('Bug', fs[0].type)
      assert_equal(526_301, fs[1].who)
      assert_equal('Task', fs[1].type)
    end
  end

  def test_removes_lost_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 44, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repositories/44/issues/44/timeline?per_page=100',
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ]
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 44
      f.issue = 44
      f.where = 'github'
    end
    load_it('type-was-attached', fb)
    assert_equal(0, fb.query('(eq what "issue-was-opened")').each.to_a.size)
    assert_equal(0, fb.query('(eq issue 44)').each.to_a.size)
  end

  def test_does_not_remove_typed_issue
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 44, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repositories/44/issues/44/timeline?per_page=100',
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ]
    )
    stub_github(
      'https://api.github.com/repositories/44/issues/45/timeline?per_page=100',
      body: [
        {
          event: 'issue_type_added', node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
          actor: { id: 42 }, created_at: Time.now
        }
      ]
    )
    stub_github('https://api.github.com/repositories/44', body: { id: 44, full_name: 'foo/foo' })
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 44
      f.issue = 44
      f.where = 'github'
    end
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 44
      f.issue = 45
      f.where = 'github'
    end
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('type-was-attached', fb)
      fs = fb.query('(eq what "issue-was-opened")').each.to_a
      refute_empty(fs)
      assert_equal(45, fs[0].issue)
      assert_equal('issue-was-opened', fs[0].what)
      assert_equal(0, fb.query('(eq issue 44)').each.to_a.size)
    end
  end

  def test_does_not_remove_issue_from_other_repository
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 50, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repositories/50/issues/46/timeline?per_page=100',
      status: 404,
      body: [
        {
          message: 'Not Found',
          documentation_url: 'https://docs.github.com/rest/issues/timeline#list-timeline-events-for-an-issue',
          status: '404'
        }
      ]
    )
    stub_github('https://api.github.com/repos/bar/bar', body: { id: 55, full_name: 'bar/bar' })
    stub_github(
      'https://api.github.com/repositories/55/issues/46/timeline?per_page=100',
      body: [
        {
          event: 'issue_type_added', node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
          actor: { id: 42 }, created_at: Time.now
        }
      ]
    )
    stub_github('https://api.github.com/repositories/55', body: { id: 55, full_name: 'bar/bar' })
    fb = Factbase.new
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 50
      f.issue = 46
      f.where = 'github'
    end
    fb.insert.then do |f|
      f.what = 'issue-was-opened'
      f.repository = 55
      f.issue = 46
      f.where = 'github'
    end
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('type-was-attached', fb, Judges::Options.new({ 'repositories' => 'foo/foo,bar/bar' }))
      assert_equal(0, fb.query('(and (eq what "issue-was-opened") (eq repository 50))').each.to_a.size)
      assert_equal(0, fb.query('(and (eq issue 46) (eq repository 50))').each.to_a.size)
      f = fb.query('(and (eq issue 46) (eq repository 55))').each.to_a
      assert_equal(2, f.size)
      assert_equal(46, f.first.issue)
      assert_equal(55, f.first.repository)
    end
  end
end
