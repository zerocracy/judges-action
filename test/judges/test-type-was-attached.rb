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
  using SmartFactbase

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
      f.where = 'github'
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

  def test_catches_type_event_by_5_repeats
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
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      begin
        stubs << stub_github(
          'https://api.github.com/repositories/42/issues/42/timeline?per_page=100',
          body: [
            {
              event: 'issue_type_added', node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
              actor: { id: 42 }, created_at: Time.now
            }
          ]
        )
        [43, 44, 45, 46].each do |issue|
          stubs << stub_github("https://api.github.com/repositories/42/issues/#{issue}/timeline?per_page=100",
                               body: [])
        end
        load_it('type-was-attached', fb)
        assert(fb.one?(what: 'type-was-attached', repository: 42, issue: 42, where: 'github',
                       type: 'Bug', who: 526_301))
        assert(fb.one?(what: 'types-were-scanned', repository: 42, latest: 46, where: 'github'))
      ensure
        stubs.each { WebMock.remove_request_stub(_1) }.clear
      end
      begin
        [47, 48].each do |issue|
          stubs << stub_github("https://api.github.com/repositories/42/issues/#{issue}/timeline?per_page=100",
                               body: [])
        end
        load_it('type-was-attached', fb)
        assert(fb.one?(what: 'types-were-scanned', repository: 42, latest: 0, where: 'github'))
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
          body: [
            {
              event: 'issue_type_added', node_id: 'ITAE_examplevq862Ga8lzwAAAAQZanzv',
              actor: { id: 42 }, created_at: Time.now
            }
          ]
        )
        load_it('type-was-attached', fb)
        assert(fb.one?(what: 'type-was-attached', repository: 42, issue: 47, where: 'github',
                       type: 'Bug', who: 526_301))
        assert(fb.one?(what: 'types-were-scanned', repository: 42, latest: 47, where: 'github'))
      ensure
        stubs.each { WebMock.remove_request_stub(_1) }.clear
      end
    end
  end
end
