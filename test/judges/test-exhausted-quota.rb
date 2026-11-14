# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe/octo'
require_relative '../fake_github'
require_relative '../test__helper'

class TestExhaustedQuota < Jp::Test
  using SmartFactbase

  {
    'eliminate-ghosts' => '/user/123',
    'erase-repository' => '/repositories/42'
  }.each do |judge, endpoint|
    define_method("test_#{judge.tr('-', '_')}_avoids_lookup_without_quota") do
      without_quota(judge, endpoint) do |_fb, _before, uri|
        assert_not_requested(:get, "#{uri}#{endpoint}")
      end
    end
    define_method("test_#{judge.tr('-', '_')}_preserves_facts_without_quota") do
      without_quota(judge, endpoint) do |fb, before, _uri|
        assert_equal(before, fb.export, 'Quota exhaustion must leave the existing facts intact')
      end
    end
  end

  def test_find_all_issues_avoids_pull_lookup_after_search_exhausts_quota
    exhausted_by_search do |_fb, uri|
      assert_not_requested(:get, "#{uri}/repos/foo/foo/pulls/45")
    end
  end

  def test_find_all_issues_does_not_insert_pull_after_search_exhausts_quota
    exhausted_by_search do |fb, _uri|
      assert_equal([44], fb.picks(what: 'pull-was-opened').map(&:issue))
    end
  end

  private

  def without_quota(judge, endpoint)
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', where: 'github', repository: 42, issue: 44, who: 123)
    before = fb.export
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      "GET #{endpoint}" => [404, { message: 'Not Found' }]
    ).run do |uri|
      octo = quota_client { |**| true }
      Fbe.stub(:octo, octo) { load_it(judge, fb) }
      yield(fb, before, uri)
    end
  end

  def exhausted_by_search
    fb = Factbase.new
    fb.with(_id: 1, what: 'pull-was-opened', where: 'github', repository: 42, issue: 44)
    created = Time.parse('2025-01-01T00:00:00Z')
    Jp::FakeGithub.new(
      'GET /rate_limit' => { rate: { remaining: 1000, limit: 1000 } },
      'GET /repos/foo/foo' => { id: 42, full_name: 'foo/foo' },
      'GET /repositories/42' => { id: 42, full_name: 'foo/foo' },
      'GET /repos/foo/foo/issues/44' => { created_at: created },
      'GET /repos/foo/foo/pulls/45' => { head: { ref: 'main' } },
      'GET /user/123' => { id: 123, login: 'alice', type: 'User' }
    ).run do |uri|
      exhausted = false
      octo = quota_client { |**| exhausted }
      search =
        lambda do |*|
          exhausted = true
          { total_count: 1, items: [{ number: 45, created_at: created, user: { id: 123 } }] }
        end
      Fbe.stub(:octo, octo) do
        Jp.stub(:qosearch, search) { load_it('find-all-issues', fb) }
      end
      yield(fb, uri)
    end
  end

  def quota_client(&)
    client = Fbe.octo(options: Judges::Options.new({}), global: {}, loog: Loog::NULL)
    octo = Object.new
    octo.define_singleton_method(:off_quota?, &)
    %i[repository repo_id_by_name repo_name_by_id issue pull_request user user_name_by_id print_trace!].each do |name|
      octo.define_singleton_method(name) { |*args, **opts| client.public_send(name, *args, **opts) }
    end
    octo
  end
end
