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

  def test_records_later_type_changes_and_removals
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, name: 'foo', full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: [
        { id: 100, event: 'issue_type_added', node_id: 'ITAE_bug', created_at: '2025-09-30 06:00:00 UTC' },
        { id: 101, event: 'issue_type_changed', node_id: 'ITCE_task', created_at: '2025-09-30 07:00:00 UTC' },
        { id: 102, event: 'issue_type_removed', node_id: 'ITRE_task', created_at: '2025-09-30 08:00:00 UTC' }
      ]
    )
    graph = Fbe::Graph::Fake.new
    events = {
      'ITAE_bug' => {
        'created_at' => Time.parse('2025-09-30 06:00:00 UTC'),
        'issue_type' => { 'id' => 'IT_bug', 'name' => 'Bug' },
        'actor' => { 'id' => 421, 'login' => 'alice' }
      },
      'ITCE_task' => {
        'created_at' => Time.parse('2025-09-30 07:00:00 UTC'),
        'issue_type' => { 'id' => 'IT_task', 'name' => 'Task' },
        'prev_issue_type' => { 'id' => 'IT_bug', 'name' => 'Bug' },
        'actor' => { 'id' => 422, 'login' => 'bob' }
      },
      'ITRE_task' => {
        'created_at' => Time.parse('2025-09-30 08:00:00 UTC'),
        'issue_type' => { 'id' => 'IT_task', 'name' => 'Task' },
        'actor' => { 'id' => 423, 'login' => 'carol' }
      }
    }
    graph.define_singleton_method(:issue_type_event) { |node_id| events[node_id] }
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    fb.with(
      _id: 2, what: 'type-was-attached', repository: 42, issue: 44, where: 'github',
      type: 'Bug', when: Time.parse('2025-09-30 06:00:00 UTC')
    )
    Fbe.stub(:github_graph, graph) do
      load_it('type-was-attached', fb)
      load_it('type-was-attached', fb)
    end
    records = fb.query("(eq what 'type-was-attached')").each.to_a
    states = records.map { |fact| [fact.type, fact['stale']&.first] }
    states.sort!
    assert_equal([%w[Bug removed], %w[Task removed]], states)
    assert(fb.one?(what: 'type-was-attached', repository: 42, issue: 44, type: 'Bug', stale: 'removed'))
    assert(fb.one?(what: 'type-was-attached', repository: 42, issue: 44, type: 'Task', stale: 'removed'))
  end
end
