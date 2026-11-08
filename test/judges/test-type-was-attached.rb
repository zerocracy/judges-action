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

  def test_sets_who_and_when_of_the_attached_type_fact
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        { id: 100, event: 'issue_type_added', node_id: 'ITAE_actor', created_at: '2025-09-30 06:14:38 UTC' }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, attached_type_event) do
      load_it('type-was-attached', fb)
    end
    fact = fb.pick(what: 'type-was-attached')
    refute_nil(fact)
    assert_equal([777], fact['who'], 'the fact must name the actor who attached the type')
    assert_equal(
      [Time.parse('2025-09-30 06:14:38 UTC')], fact['when'],
      'the fact must carry the time of the type event, not the time of the run'
    )
    assert_nil(fact['stale'])
  end

  def test_skips_removed_type_without_name
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        { id: 101, event: 'issue_type_removed', node_id: 'ITRE_unknown', created_at: '2025-09-30 06:14:38 UTC' }
      ]
    )
    fake = Fbe::Graph::Fake.new
    fake.define_singleton_method(:issue_type_event) do |_node_id|
      {
        'type' => 'IssueTypeRemovedEvent',
        'created_at' => Time.parse('2025-09-30 06:14:38 UTC'),
        'issue_type' => { 'id' => 'IT_x', 'name' => nil },
        'actor' => { 'login' => 'user', 'type' => 'User', 'id' => 777, 'name' => nil, 'email' => nil }
      }
    end
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, fake) do
      load_it('type-was-attached', fb)
    end
    assert_empty(
      fb.query("(eq what 'type-was-attached')").each.to_a,
      'a removed type without a name cannot attach anything'
    )
  end

  def test_ignores_timeline_that_is_not_an_array
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: { message: 'not a timeline' }
    )
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('type-was-attached', fb)
    end
    assert_empty(fb.query("(eq what 'type-was-attached')").each.to_a, 'a non-array timeline has no events to read')
    assert(
      fb.one?(what: 'issue-was-opened', repository: 42, issue: 44, where: 'github'),
      'an unreadable timeline must not stale the issue'
    )
  end

  private

  def attached_type_event
    fake = Fbe::Graph::Fake.new
    fake.define_singleton_method(:issue_type_event) do |_node_id|
      {
        'type' => 'IssueTypeAddedEvent',
        'created_at' => Time.parse('2025-09-30 06:14:38 UTC'),
        'issue_type' => { 'id' => 'IT_x', 'name' => 'Bug', 'description' => 'd' },
        'prev_issue_type' => nil,
        'actor' => { 'login' => 'user', 'type' => 'User', 'id' => 777, 'name' => nil, 'email' => nil }
      }
    end
    fake
  end
end
