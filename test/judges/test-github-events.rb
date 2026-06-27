# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fbe'
require 'fbe/github_graph'
require 'json'
require 'judges/options'
require 'loog'
require_relative '../test__helper'

class TestGithubEvents < Jp::Test
  using SmartFactbase

  def test_create_tag_event
    rate_limit_up
    stub_event(
      {
        id: 42,
        created_at: Time.now.to_s,
        actor: { id: 42 },
        type: 'CreateEvent',
        repo: { id: 42 },
        payload: { ref_type: 'tag', ref: 'foo' }
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/create-tag-event') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "tag-was-created")').each.first
    refute_nil(f)
    assert_equal(42, f.who)
    assert_equal('foo', f.tag)
  end

  def test_skip_tag_event_with_unknown_payload_ref_type
    rate_limit_up
    stub_event(
      {
        id: 11,
        created_at: Time.now.to_s,
        actor: { id: 42 },
        type: 'CreateEvent',
        repo: { id: 42 },
        payload: { ref_type: 'unknown', ref: 'foo' }
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-tag-event-with-unknown-payload-ref-type') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11))
    assert(fb.none?(event_type: 'CreateEvent'))
  end

  def test_skip_watch_event
    rate_limit_up
    stub_event({ id: 42, created_at: Time.now.to_s, action: 'created', type: 'WatchEvent', repo: { id: 42 } })
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-watch-event') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.size)
  end

  def test_skip_event_when_user_equals_pr_author
    rate_limit_up
      .to_return(
        status: 200,
        body: {
          user: {
            login: 'test',
            id: 526_200,
            node_id: 'MDQ6VXNlcjUyNjMwMQ==',
            type: 'User'
          },
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: {
          'Content-Type': 'application/json',
          'X-RateLimit-Remaining' => '999'
        }
      )
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-event-when-user-equals-pr-author') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(42, f.first.who)
    assert_equal(43, f[1].who)
    assert_nil(f[2])
  end

  def test_add_only_approved_pull_request_review_events
    rate_limit_up
      .to_return(
        status: 200,
        body: {
          user: {
            login: 'test',
            id: 526_200,
            type: 'User',
            site_admin: false
          },
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: {
          'Content-Type': 'application/json',
          'X-RateLimit-Remaining' => '999'
        }
      )
    fb = Factbase.new
    VCR.use_cassette('github-events/add-only-approved-pull-request-review-events') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(1, f.count)
    assert_equal(42, f.first.who)
  end

  def test_skip_issue_was_opened_event
    rate_limit_up
    fb = Factbase.new
    op = fb.insert
    op.event_id = 100_500
    op.what = 'issue-was-opened'
    op.where = 'github'
    op.repository = 42
    op.issue = 1347
    VCR.use_cassette('github-events/skip-issue-was-opened-event') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "issue-was-opened")').each.to_a
    assert_equal(1, f.length)
  end

  def test_skip_issue_was_closed_event
    rate_limit_up
    fb = Factbase.new
    op = fb.insert
    op.event_id = 100_500
    op.what = 'issue-was-closed'
    op.where = 'github'
    op.repository = 42
    op.issue = 1347
    VCR.use_cassette('github-events/skip-issue-was-closed-event') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "issue-was-closed")').each.to_a
    assert_equal(1, f.length)
  end

  def test_skip_issue_event_with_unknown_payload_action
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-issue-event-with-unknown-payload-action') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_125))
    assert(fb.none?(event_type: 'IssuesEvent'))
  end

  def test_watch_pull_request_review_events
    rate_limit_up
      .to_return(
        status: 200,
        body: {
          user: {
            login: 'test',
            id: 526_200,
            node_id: 'MDQ6VXNlcjE2NDYwMjA=',
            type: 'User',
            site_admin: false
          },
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'X-RateLimit-Remaining' => '999'
        }
      )
    fb = Factbase.new
    VCR.use_cassette('github-events/watch-pull-request-review-events') do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(2, f.count)
    assert_equal(42, f.first.who)
    assert_equal(55, f.last.who)
    assert_equal(2, f.first.review_comments)
    assert_equal(2, f.last.review_comments)
  end

  def test_skip_pull_request_review_event_with_unknown_payload_action
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-pull-request-review-event-with-unknown-payload-action') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_124))
    assert(fb.none?(event_type: 'PullRequestReviewEvent'))
  end

  def test_release_event_contributors
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/release-event-contributors') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 820463873) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_equal([526_301, 526_302], f.first[:contributors])
    assert_equal([2_566_462, 2_566_463, 2_566_464], f.last[:contributors])
    assert_equal(2, f.first.commits)
    assert_equal(22, f.first.hoc)
    assert_equal('4683257342e98cd94becc2aa49900e720bd792e9', f.first.last_commit)
    assert_equal(4, f.last.commits)
    assert_equal(90, f.last.hoc)
    assert_equal('a50489ead5e8aa6', f.last.last_commit)
  end

  def test_release_event_contributors_without_last_release_tag_and_with_release_id
    rate_limit_up
    stub_event(
      {
        id: '10',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 42,
          name: 'foo/foo',
          url: 'https://api.github.com/repos/foo/foo'
        },
        payload: {
          action: 'published',
          release: {
            id: 471_000,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '0.0.3',
            name: 'v0.0.3',
            created_at: Time.parse('2024-08-05T00:51:39Z'),
            published_at: Time.parse('2024-08-05T00:52:07Z')
          }
        },
        public: true,
        created_at: Time.parse('2024-08-06T00:52:08Z'),
        org: {
          id: 24_234_201,
          login: 'foo'
        }
      }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'A new release was published in this repo by the crew: v0.0.2.'
      f.event_id = 30_406
      f.event_type = 'ReleaseEvent'
      f.is_human = 1
      f.release_id = 470_000
      f.repository = 42
      f.what = 'release-published'
      f.when = Time.parse('2024-08-02 21:45:00 UTC')
      f.where = 'github'
      f.who = 526_301
    end
    VCR.use_cassette('github-events/release-event-contributors-without-last-release-tag-and-with-release-id') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_nil(f.first[:tag])
    refute_nil(f.first[:release_id])
    assert_equal([2_566_462, 2_566_463, 2_566_464], f.last[:contributors])
  end

  def test_release_event_contributors_without_last_release_tag_and_without_release_id
    rate_limit_up
    stub_event(
      {
        id: '10',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 42,
          name: 'foo/foo',
          url: 'https://api.github.com/repos/foo/foo'
        },
        payload: {
          action: 'published',
          release: {
            id: 471_000,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '0.0.3',
            name: 'v0.0.3',
            created_at: Time.parse('2024-08-05T00:51:39Z'),
            published_at: Time.parse('2024-08-05T00:52:07Z')
          }
        },
        public: true,
        created_at: Time.parse('2024-08-06T00:52:08Z'),
        org: {
          id: 24_234_201,
          login: 'foo'
        }
      }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The release v0.0.2 was published in the repo by the crew.'
      f.event_id = 30_407
      f.event_type = 'ReleaseEvent'
      f.is_human = 1
      f.repository = 42
      f.what = 'release-published'
      f.when = Time.parse('2024-08-02 21:45:00 UTC')
      f.where = 'github'
      f.who = 526_301
    end
    VCR.use_cassette('github-events/release-event-contributors-without-last-release-tag-and-without-release-id') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_nil(f.first[:tag])
    assert_nil(f.first[:release_id])
    assert_equal([526_301, 526_302], f.last[:contributors])
  end

  def test_event_for_renamed_repository
    rate_limit_up
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'The release v1.2.2 was published recently by the developer in this repo.'
      f.event_id = 35_207
      f.event_type = 'ReleaseEvent'
      f.is_human = 1
      f.release_id = 20_000
      f.repository = 111
      f.what = 'release-published'
      f.when = Time.parse('2024-10-31 21:45:00 UTC')
      f.where = 'github'
      f.who = 526_301
    end
    VCR.use_cassette('github-events/event-for-renamed-repository') do
      load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/new_baz' }))
    end
    f = fb.query('(eq what "release-published")').each.to_a.last
    assert_equal(111, f.repository)
    assert_equal('v1.2.3', f.tag)
    refute_match(/old_baz/, f.details)
  end

  def test_skip_release_event_with_unknown_payload_action
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-release-event-with-unknown-payload-action') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 55_555))
  end

  def test_pull_request_event_with_comments
    fb = Factbase.new
    VCR.use_cassette('github-events/pull-request-event-with-comments') do
      load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'zerocracy/baza', 'testing' => true }))
    end
    f = fb.query('(eq what "pull-was-merged")').each.first
    assert_equal(4, f.comments)
    assert_equal(2, f.comments_to_code)
    assert_equal(2, f.comments_by_author)
    assert_equal(2, f.comments_by_reviewers)
    assert_equal(4, f.comments_appreciated)
    assert_equal(1, f.comments_resolved)
  end

  def test_count_numbers_of_workflow_builds
    fb = Factbase.new
    VCR.use_cassette('github-events/count-numbers-of-workflow-builds') do
      load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'zerocracy/baza', 'testing' => true }))
    end
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 42))').each.first
    assert_equal(4, f.succeeded_builds)
    assert_equal(2, f.failed_builds)
  end

  def test_counts_workflow_builds_from_github
    fb = Factbase.new
    VCR.use_cassette('github-events/count-numbers-of-workflow-builds-only-from-github') do
      load_it(
        'github-events',
        fb,
        Judges::Options.new({ 'repositories' => 'zerocracy/judges-action', 'testing' => true })
      )
    end
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 43))').each.first
    assert_nil(f)
  end

  def test_no_have_access_to_resource_by_integration
    rate_limit_up
    fb = Factbase.new
    ex =
      assert_raises(RuntimeError) do
        VCR.use_cassette('github-events/no-have-access-to-resource-by-integration') do
          load_it('github-events', fb)
        end
      end
    assert_equal("@GithubUser doesn't have access to the foo/foo repository, maybe it's private", ex.message)
    assert_equal(0, fb.size)
  end

  def test_no_have_access_to_resource_by_integration_in_handle_exception
    rate_limit_up
    fb = Factbase.new
    ex =
      assert_raises(RuntimeError) do
        VCR.use_cassette('github-events/no-have-access-to-resource-by-integration-in-handle-exception') do
          load_it('github-events', fb)
        end
      end
    assert_equal("You doesn't have access to the foo/foo repository, maybe it's private", ex.message)
    assert_equal(0, fb.size)
  end

  def test_skip_push_event_if_push_to_non_default_branch
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-push-event-if-push-to-non-default-branch') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate'))
    assert(fb.none?(what: 'git-was-pushed'))
  end

  def test_success_add_push_event_to_factbase
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/success-add-push-event-to-factbase') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_111))
    assert(
      fb.one?(
        what: 'git-was-pushed', event_id: 11_111, when: Time.parse('2025-06-26 19:03:16 UTC'),
        event_type: 'PushEvent', repository: 42, who: 43, push_id: 2412, ref: 'refs/heads/master',
        commit: 'f5d59b035', default_branch: 'master', to_master: 1,
        details:
          'A new Git push #2412 has arrived to foo/foo, made by @yegor256 (default branch is "master"), ' \
          'not associated with any pull request.'
      )
    )
  end

  def test_push_event_by_owner_sets_by_owner_to_one
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/push-event-by-owner-sets-by-owner-to-one') do
      load_it('github-events', fb)
    end
    push = fb.query('(and (eq what "git-was-pushed") (eq event_id 22222))').each.first
    refute_nil(push)
    assert_equal(1, push.by_owner)
    assert_equal(50, push.who)
  end

  def test_push_event_by_non_owner_sets_by_owner_to_none
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/push-event-by-non-owner-sets-by-owner-to-none') do
      load_it('github-events', fb)
    end
    push = fb.query('(and (eq what "git-was-pushed") (eq event_id 33333))').each.first
    refute_nil(push)
    assert_nil(push['by_owner'])
    assert_equal(60, push.who)
  end

  def test_success_add_opened_pull_request_event_to_factbase
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/success-add-opened-pull-request-event-to-factbase') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_122))
    assert(
      fb.one?(
        what: 'pull-was-opened', event_id: 11_122, when: Time.parse('2025-06-27 19:00:05 UTC'),
        event_type: 'PullRequestEvent', repository: 42, who: 45, issue: 456, branch: '487',
        details: 'The pull request foo/foo#456 has been opened by @user.'
      )
    )
  end

  def test_skip_fill_up_event_if_event_exists_in_factbase_by_given_uniques
    rate_limit_up
    fb = Factbase.new
    fb.with(what: 'pull-was-opened', repository: 42, where: 'github', who: 45, issue: 456)
    VCR.use_cassette('github-events/skip-fill-up-event-if-event-exists-in-factbase-by-given-uniques') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_122))
    assert(fb.one?(what: 'pull-was-opened', where: 'github', repository: 42, who: 45, issue: 456))
  end

  def test_skip_duplicate_opened_pull_request_event_without_who
    rate_limit_up
    fb = Factbase.new
    fb.with(
      _id: 1, branch: 'fix-bug', details: 'The missing pull foo/foo#187 has been opened by @user.',
      issue: 187, repository: 42, what: 'pull-was-opened', when: '2025-10-16T19:00:00Z', where: 'github'
    )
    VCR.use_cassette('github-events/skip-duplicate-opened-pull-request-event-without-who') do
      load_it('github-events', fb)
    end
    assert(fb.one?(what: 'pull-was-opened', where: 'github', repository: 42, issue: 187))
  end

  def test_skip_pull_request_event_with_unknown_payload_action
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-pull-request-event-with-unknown-payload-action') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_123))
    assert(fb.none?(event_type: 'PullRequestEvent'))
  end

  def test_prevent_creation_of_duplicate_facts_upon_multiple_pr_closures
    rate_limit_up
    stub_event(
      {
        id: '123123111',
        type: 'PullRequestEvent',
        actor: { id: 411, login: 'user' },
        repo: { id: 43, name: 'bar', full_name: 'bar/bar' },
        payload: {
          action: 'closed',
          number: 305,
          pull_request: {
            id: 249_156, number: 305,
            head: {
              label: 'foo:origin/master', ref: 'origin/master', sha: '42b24481',
              user: { id: 411, login: 'user' },
              repo: { id: 42,  name: 'foo', full_name: 'foo/foo' }
            },
            base: {
              label: 'bar:master', ref: 'master', sha: '9f4767929',
              user: { id: 422, login: 'user2' },
              repo: { id: 43,  name: 'bar', full_name: 'bar/bar' }
            }
          }
        },
        public: true,
        created_at: Time.parse('2025-05-04 03:46:04 UTC')
      },
      {
        id: '123123222',
        type: 'PullRequestEvent',
        actor: { id: 411, login: 'user' },
        repo: { id: 43, name: 'bar', full_name: 'bar/bar' },
        payload: {
          action: 'closed',
          number: 305,
          pull_request: {
            id: 249_156, number: 305,
            head: {
              label: 'foo:origin/master', ref: 'origin/master', sha: '42b24481',
              user: { id: 411, login: 'user' },
              repo: { id: 42,  name: 'foo', full_name: 'foo/foo' }
            },
            base: {
              label: 'bar:master', ref: 'master', sha: '9f4767929',
              user: { id: 422, login: 'user2' },
              repo: { id: 43,  name: 'bar', full_name: 'bar/bar' }
            }
          }
        },
        public: true,
        created_at: Time.parse('2025-05-04 03:46:04 UTC')
      }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('github-events/prevent-creation-of-duplicate-facts-upon-multiple-pr-closures') do
        load_it('github-events', fb)
      end
    end
    assert_equal(1, fb.query('(eq what "pull-was-closed")').each.to_a.size)
  end

  def test_adds_created_issue_comment_event
    skip('This type of event is not needed now')
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/success-add-created-issue-comment-event-to-factbase') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 22_222))
    assert(
      fb.one?(
        what: 'comment-was-posted', event_id: 22_222, when: Time.parse('2025-06-27 19:00:00 UTC'), issue: 789,
        event_type: 'IssueCommentEvent', repository: 42, who: 43, comment_id: 30_093, comment_body: 'some text',
        details: 'A new comment #30093 has been posted to foo/foo#789 by @yegor256.'
      )
    )
  end

  def test_skip_issue_comment_event_with_unknown_payload_action
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/skip-issue-comment-event-with-unknown-payload-action') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 22_223))
    assert(fb.none?(event_type: 'IssueCommentEvent'))
  end

  def test_stop_scanning_if_number_event_greater_than_max_events
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/stop-scanning-if-number-event-greater-than-max-events') do
      load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'max_events' => 3 }))
    end
    assert_equal(4, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 14))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 14))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 13))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 12))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 11))
  end

  def test_stop_scanning_if_event_id_less_or_eq_than_latest
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, _time: Time.now.utc, where: 'github', repository: 42, events_were_scanned: 14, what: 'iterate')
    VCR.use_cassette('github-events/stop-scanning-if-event-id-less-or-eq-than-latest') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 15))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 15))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 14))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 13))
  end

  def test_max_events_guard_fires_once
    rate_limit_up
    fb = Factbase.new
    loog = Loog::Buffer.new
    VCR.use_cassette('github-events/max-events-guard-fires-once') do
      load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'max_events' => 2 }), loog:)
    end
    assert_equal(1, loog.to_s.scan('Already scanned').size)
  end

  def test_latest_id_guard_fires_once
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, _time: Time.now.utc, where: 'github', repository: 42, events_were_scanned: 13, what: 'iterate')
    loog = Loog::Buffer.new
    VCR.use_cassette('github-events/latest-id-guard-fires-once') do
      load_it('github-events', fb, loog:)
    end
    assert_equal(1, loog.to_s.scan('good stop').size)
  end

  def test_skip_fill_up_if_event_exists_in_factbase
    rate_limit_up
    fb = Factbase.new
    fb.with(what: 'tag-was-created', event_type: 'CreateEvent', repository: 42, where: 'github', event_id: 15)
    VCR.use_cassette('github-events/skip-fill-up-if-event-exists-in-factbase') do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 15))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 15))
  end

  def test_empty_events
    rate_limit_up
    fb = Factbase.new
    VCR.use_cassette('github-events/empty-events') do
      load_it('github-events', fb)
    end
    assert_equal(0, fb.all.size)
  end

  def test_finished_scanning_with_saving_latest_event_id
    rate_limit_up
    fb = Factbase.new
    fb.with(_id: 1, _time: Time.now.utc, where: 'github', repository: 42, events_were_scanned: 12, what: 'iterate')
    rate_limit_up
    stub_event(
      {
        id: '11127',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'closed',
          pull_request: { number: 123, head: { ref: 'feature-branch', sha: 'abc123' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/rescues-forbidden-on-closed-pull-request-lookup') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_127))
  end

  def test_rescues_deprecated_on_closed_pull_request_lookup
    rate_limit_up
    stub_event(
      {
        id: '11130',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'closed',
          pull_request: { number: 123, head: { ref: 'feature-branch', sha: 'abc123' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/rescues-deprecated-on-closed-pull-request-lookup') do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_130))
  end

  def test_rescues_forbidden_on_closed_pull_request_reviews_lookup
    rate_limit_up
    stub_event(
      {
        id: 1,
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42 },
        payload: {
          action: 'closed',
          pull_request: { number: 123, head: { ref: 'feature', sha: 'abc123' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }
    )
    stub_request(:get, 'https://api.github.com/user/45').to_return(
      body: { id: 45, login: 'user' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123',
      body: { number: 123, head: { ref: 'feature', sha: 'abc123' } }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/123/reviews?per_page=100').to_return(
      { status: 403, body: { message: 'Resource not accessible by integration' }.to_json,
        headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '999' } },
      { status: 200, body: [].to_json,
        headers: { 'Content-Type': 'application/json', 'X-RateLimit-Remaining' => '999' } }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/abc123/check-runs?per_page=100',
                body: { total_count: 0, check_runs: [] })
    fb = Factbase.new
    f = fb.insert
    f.what = 'pull-was-merged'
    f.repository = 42
    f.issue = 123
    f.where = 'github'
    f.when = Time.parse('2025-06-27 19:00:05 UTC')
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-merged")').each.first
    refute_nil(f)
    assert_nil(f['review'])
  end

  def test_closed_pull_request_event_with_nil_additions_or_deletions
    rate_limit_up
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('github-events/closed-pull-request-event-with-nil-additions-or-deletions') do
        load_it('github-events', fb)
      end
    end
    first, second = fb.query('(eq what "pull-was-merged")').each.to_a
    refute_nil(first)
    assert_equal(5, first.hoc)
    refute_nil(second)
    assert_equal(7, second.hoc)
  end

  def test_closed_pull_request_with_exist_review_and_code_suggestions
    rate_limit_up
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      VCR.use_cassette('github-events/closed-pull-request-with-exist-review-and-code-suggestions') do
        load_it('github-events', fb)
      end
    end
    f = fb.query('(eq what "pull-was-merged")').each.to_a.first
    refute_nil(f)
    assert_equal(Time.parse('2025-10-20 18:05:00 UTC'), f.review)
    assert_equal(2, f.suggestions)
  end

  def test_release_event_with_nil_compare_response
    rate_limit_up
    stub_event(
      {
        id: '100',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 42,
          name: 'foo/foo',
          url: 'https://api.github.com/repos/foo/foo'
        },
        payload: {
          action: 'published',
          release: {
            id: 999_000,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '1.0.0',
            name: 'v1.0.0',
            created_at: Time.parse('2024-11-30T00:51:39Z'),
            published_at: Time.parse('2024-11-30T00:52:07Z')
          }
        },
        public: true,
        created_at: Time.parse('2024-11-30T00:52:08Z')
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/release-event-with-nil-compare-response') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(1, f.count)
    assert_equal([526_301], f.first[:contributors])
  end

  def test_release_event_rescues_forbidden_contributors_and_compare
    rate_limit_up
    stub_event(
      {
        id: '101',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 42,
          name: 'foo/foo',
          url: 'https://api.github.com/repos/foo/foo'
        },
        payload: {
          action: 'published',
          release: {
            id: 999_001,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '1.0.0',
            name: 'v1.0.0',
            created_at: Time.parse('2024-11-30T00:51:39Z'),
            published_at: Time.parse('2024-11-30T00:52:07Z')
          }
        },
        public: true,
        created_at: Time.parse('2024-11-30T00:52:08Z')
      }
    )
    fb = Factbase.new
    VCR.use_cassette('github-events/release-event-rescues-forbidden-contributors-and-compare') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(1, f.count)
    refute_includes(f.first.all_properties, 'contributors')
    refute_includes(f.first.all_properties, 'commits')
    refute_includes(f.first.all_properties, 'hoc')
  end

  def test_release_event_rescues_deprecated_release_compare
    rate_limit_up
    stub_event(
      {
        id: '102',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 42,
          name: 'foo/foo',
          url: 'https://api.github.com/repos/foo/foo'
        },
        payload: {
          action: 'published',
          release: {
            id: 999_002,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '1.1.0',
            name: 'v1.1.0',
            created_at: Time.parse('2024-12-01T00:51:39Z'),
            published_at: Time.parse('2024-12-01T00:52:07Z')
          }
        },
        public: true,
        created_at: Time.parse('2024-12-01T00:52:08Z')
      }
    )
    fb = Factbase.new
    fb.insert.then do |f|
      f.details = 'A previous release was published in this repo.'
      f.event_id = 100
      f.event_type = 'ReleaseEvent'
      f.repository = 42
      f.tag = '0.9.0'
      f.what = 'release-published'
      f.when = Time.parse('2024-11-29 00:52:08 UTC')
      f.where = 'github'
      f.who = 526_301
    end
    VCR.use_cassette('github-events/release-event-rescues-deprecated-release-compare') do
      load_it('github-events', fb)
    end
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_equal('1.1.0', f.last.tag)
    refute_includes(f.last.all_properties, 'contributors')
    refute_includes(f.last.all_properties, 'commits')
    refute_includes(f.last.all_properties, 'hoc')
  end

  def test_write_supervision_log_if_raise_error
    rate_limit_up
    stub_event(
      {
        id: 11,
        created_at: 'wrong date',
        actor: { id: 42 },
        type: 'CreateEvent',
        repo: { id: 42 },
        payload: { ref_type: 'unknown', ref: 'foo' }
      }
    )
    loog = Loog::Buffer.new
    assert_raises(NoMethodError) do
      VCR.use_cassette('github-events/write-supervision-log-if-raise-error') do
        load_it('github-events', Factbase.new, loog:)
      end
    end
    loog.to_s.then do |s|
      assert_match('"repo": "foo/foo"', s)
      assert_match('"created_at": "wrong date"', s)
    end
  end

  private

  def stub_event(*json)
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: json.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
  end
end
