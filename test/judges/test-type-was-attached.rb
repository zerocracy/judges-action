# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/github_graph'
require_relative '../test__helper'

class TestTypeWasAttached < Jp::Test
  using SmartFactbase

  def test_marks_stale_when_timeline_returns_not_found
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      status: 404,
      body: { message: 'Not Found', documentation_url: 'https://docs.github.com', status: '404' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('type-was-attached', fb)
    assert(
      fb.one?(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github', stale: 'issue'),
      '404 is permanent — issue must be marked stale via Jp.issue_was_lost'
    )
  end

  def test_rescues_forbidden_on_timeline_lookup
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      status: 403,
      body: { message: 'Resource not accessible by integration' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    load_it('type-was-attached', fb)
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — fact must NOT be marked stale; next cycle will retry the timeline lookup'
    )
  end

  def test_marks_stale_when_graphql_actor_is_nil
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        {
          id: 100,
          event: 'issue_type_added',
          node_id: 'ITAE_orphan_actor',
          created_at: '2025-09-30 06:14:38 UTC'
        }
      ]
    )
    fake = Fbe::Graph::Fake.new
    fake.define_singleton_method(:issue_type_event) do |_node_id|
      {
        'type' => 'IssueTypeAddedEvent',
        'created_at' => Time.parse('2025-09-30 06:14:38 UTC'),
        'issue_type' => { 'id' => 'IT_x', 'name' => 'Bug', 'description' => 'd' },
        'prev_issue_type' => nil,
        'actor' => { 'login' => nil, 'type' => nil, 'id' => nil, 'name' => nil, 'email' => nil }
      }
    end
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, fake) do
      load_it('type-was-attached', fb)
    end
    f = fb.query("(eq what 'type-was-attached')").each.first
    refute_nil(f, 'the fact must still be created when the actor is deleted')
    assert_nil(f['who'], 'who must not be set to nil for a deleted GraphQL actor')
    assert_equal(['who'], f['stale'], 'a deleted GraphQL actor must mark the fact stale on who')
    assert_match(/an unknown actor/, f['details'].first)
  end

  def test_rescues_read_timeout_on_timeline_lookup
    rackenv = ENV.fetch('RACK_ENV', nil)
    ENV['RACK_ENV'] = 'test'
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_request(:get, 'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100')
      .to_raise(Net::ReadTimeout)
    stub_typed(45)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:github_graph, typing) { load_it('type-was-attached', fb) }
    assert(
      fb.one?(what: 'type-was-attached', issue: 45, type: 'Bug'),
      'a read timeout on the timeline lookup did not let the judge go on to the next issue'
    )
  ensure
    rackenv.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = rackenv
  end

  def test_rescues_connection_failure_on_repo_lookup
    rackenv = ENV.fetch('RACK_ENV', nil)
    ENV['RACK_ENV'] = 'test'
    WebMock.disable_net_connect!
    rate_limit_up
    stub_request(:get, 'https://api.github.com/repositories/42')
      .to_raise(Errno::ECONNRESET).then
      .to_return(
        body: { id: 42, full_name: 'foo/foo' }.to_json,
        headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '999' }
      )
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_typed(45)
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
      .with(_id: 2, what: 'issue-was-opened', repository: 42, issue: 45, where: 'github')
    Fbe.stub(:github_graph, typing) { load_it('type-was-attached', fb) }
    assert(
      fb.one?(what: 'type-was-attached', issue: 45, type: 'Bug'),
      'a reset connection on the repository lookup did not let the judge go on to the next issue'
    )
  ensure
    rackenv.nil? ? ENV.delete('RACK_ENV') : ENV['RACK_ENV'] = rackenv
  end

  private

  def stub_typed(issue)
    stub_github(
      "https://api.github.com/repos/foo/foo/issues/#{issue}/timeline?per_page=100",
      body: [{ id: 100, event: 'issue_type_added', node_id: 'ITAE_x', created_at: '2025-09-30 06:14:38 UTC' }]
    )
  end

  def typing
    fake = Fbe::Graph::Fake.new
    fake.define_singleton_method(:issue_type_event) do |_node_id|
      {
        'created_at' => Time.parse('2025-09-30 06:14:38 UTC'),
        'issue_type' => { 'name' => 'Bug' },
        'actor' => { 'login' => 'jeff', 'id' => 5 }
      }
    end
    fake
  end
end
