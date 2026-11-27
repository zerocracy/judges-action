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

  def test_keeps_type_attached_after_it_was_added_back
    seed = Random.new_seed
    type = "Ошибка#{Random.new(seed).rand(1..9999)}"
    fb = attached(type, %w[A1 R1 A2])
    refute_empty(
      fb.query("(and (eq what 'type-was-attached') (eq type '#{type}') (absent stale))").each.to_a,
      "the type #{type.inspect} added back after removal is not attached, seed #{seed}"
    )
  end

  def test_dont_duplicate_type_added_twice
    seed = Random.new_seed
    type = "Задача#{Random.new(seed).rand(1..9999)}"
    fb = attached(type, %w[A1 A2])
    assert_equal(
      1, fb.query("(and (eq what 'type-was-attached') (eq type '#{type}'))").each.to_a.size,
      "the type #{type.inspect} added twice is attached more than once, seed #{seed}"
    )
  end

  def test_dont_attach_type_removed_after_it_was_added_back
    seed = Random.new_seed
    type = "Фича#{Random.new(seed).rand(1..9999)}"
    fb = attached(type, %w[A1 R1 A2 R2])
    assert_empty(
      fb.query("(and (eq what 'type-was-attached') (eq type '#{type}') (absent stale))").each.to_a,
      "the type #{type.inspect} removed for the second time is still attached, seed #{seed}"
    )
  end

  private

  def attached(type, nodes)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github('https://api.github.com/repositories/42', body: { id: 42, full_name: 'foo/foo' })
    stub_github('https://api.github.com/repos/foo/foo', body: { id: 42, full_name: 'foo/foo' })
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/44/timeline?per_page=100',
      body: nodes.map.with_index do |node, i|
        {
          id: 100 + i,
          event: node.start_with?('A') ? 'issue_type_added' : 'issue_type_removed',
          node_id: node,
          created_at: "2025-09-30 06:1#{i}:38 UTC"
        }
      end
    )
    fake = Fbe::Graph::Fake.new
    fake.define_singleton_method(:issue_type_event) do |node|
      {
        'type' => node.start_with?('A') ? 'IssueTypeAddedEvent' : 'IssueTypeRemovedEvent',
        'created_at' => Time.parse('2025-09-30 06:14:38 UTC'),
        'issue_type' => { 'id' => 'IT_x', 'name' => type, 'description' => 'd' },
        'prev_issue_type' => nil,
        'actor' => { 'login' => 'jeff', 'type' => 'User', 'id' => 4242, 'name' => 'Jeff', 'email' => nil }
      }
    end
    fb = Factbase.new
    fb.with(_id: 1, what: 'issue-was-opened', repository: 42, issue: 44, where: 'github')
    Fbe.stub(:github_graph, fake) do
      load_it('type-was-attached', fb)
    end
    fb
  end
end
