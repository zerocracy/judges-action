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
