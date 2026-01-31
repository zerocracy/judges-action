# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'json'
require 'judges/options'
require 'fbe'
require 'fbe/github_graph'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestGithubEvents < Jp::Test
  using SmartFactbase

  def test_create_tag_event
    WebMock.disable_net_connect!
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
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(eq what "tag-was-created")').each.first
    refute_nil(f)
    assert_equal(42, f.who)
    assert_equal('foo', f.tag)
  end

  def test_skip_tag_event_with_unknown_payload_ref_type
    WebMock.disable_net_connect!
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
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11))
    assert(fb.none?(event_type: 'CreateEvent'))
  end

  def test_skip_watch_event
    WebMock.disable_net_connect!
    rate_limit_up
    stub_event(
      {
        id: 42,
        created_at: Time.now.to_s,
        action: 'created',
        type: 'WatchEvent',
        repo: { id: 42 }
      }
    )
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.size)
  end

  def test_skip_event_when_user_equals_pr_author
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: [
        {
          id: '40623323541',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 42,
            login: 'yegor256',
            display_login: 'yegor256',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'yegor256',
                id: 42,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_142,
              number: 93,
              head: { ref: '93', sha: 'e50388', repo: { id: 41, name: 'judges' } },
              base: { ref: 'master', sha: 'b33151', repo: { id: 42, name: 'judges' } }
            }
          }
        },
        {
          id: '40623323542',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 526_200,
            login: 'test',
            display_login: 'test',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_142,
              number: 93,
              head: { ref: '93', sha: 'e50388', repo: { id: 41, name: 'judges' } },
              base: { ref: 'master', sha: 'b33151', repo: { id: 42, name: 'judges' } }
            }
          }
        },
        {
          id: '40623323543',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 43,
            login: 'test',
            display_login: 'test',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_142,
              number: 93,
              head: { ref: '93', sha: 'e50388', repo: { id: 41, name: 'judges' } },
              base: { ref: 'master', sha: 'b33151', repo: { id: 42, name: 'judges' } }
            }
          }
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/43').to_return(
      body: { id: 43, login: 'user' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/526200').to_return(
      body: { id: 526_200, login: 'test' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/93')
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
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(42, f.first.who)
    assert_equal(43, f[1].who)
    assert_nil(f[2])
  end

  def test_add_only_approved_pull_request_review_events
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: [
        {
          id: '40623323541',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 42,
            login: 'torvalds',
            display_login: 'torvalds',
            gravatar_id: ''
          },
          repo: {
            id: 42,
            name: 'yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              user: {
                login: 'torvalds',
                id: 42,
                type: 'User'
              },
              state: 'approved'
            },
            pull_request: {
              id: 1_990_323_142,
              number: 93
            }
          }
        },
        {
          id: '40623323542',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 43,
            login: 'yegor256',
            display_login: 'yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              user: {
                login: 'yegor256',
                id: 43,
                type: 'User'
              },
              state: 'commented'
            },
            pull_request: {
              id: 1_990_323_142,
              number: 93
            }
          }
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/43').to_return(
      body: { id: 43, login: 'yegor256' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/526200').to_return(
      body: { id: 526_200, login: 'test' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/93')
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
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(1, f.count)
    assert_equal(42, f.first.who)
  end

  def test_skip_issue_was_opened_event
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: [
        {
          id: 40_623_323_541,
          type: 'IssuesEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 42,
            login: 'yegor256',
            display_login: 'yegor256',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'opened',
            issue: {
              number: 1347,
              state: 'open',
              title: 'Found a bug',
              body: "I'm having a problem with this."
            }
          }
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/issues/1347').to_return(
      status: 200,
      body: { number: 1347, state: 'open' }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    op = fb.insert
    op.event_id = 100_500
    op.what = 'issue-was-opened'
    op.where = 'github'
    op.repository = 42
    op.issue = 1347
    load_it('github-events', fb)
    f = fb.query('(eq what "issue-was-opened")').each.to_a
    assert_equal(1, f.length)
  end

  def test_skip_issue_was_closed_event
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: [
        {
          id: 40_623_323_541,
          type: 'IssuesEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 42,
            login: 'yegor256',
            display_login: 'yegor256',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'closed',
            issue: {
              number: 1347,
              state: 'closed',
              title: 'Found a bug',
              body: "I'm having a problem with this."
            }
          }
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/issues/1347').to_return(
      status: 200,
      body: { number: 1347, state: 'closed' }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    op = fb.insert
    op.event_id = 100_500
    op.what = 'issue-was-closed'
    op.where = 'github'
    op.repository = 42
    op.issue = 1347
    load_it('github-events', fb)
    f = fb.query('(eq what "issue-was-closed")').each.to_a
    assert_equal(1, f.length)
  end

  def test_skip_issue_event_with_unknown_payload_action
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11125',
        type: 'IssuesEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'unknown',
          issue: { number: 123 }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_125))
    assert(fb.none?(event_type: 'IssuesEvent'))
  end

  def test_watch_pull_request_review_events
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
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: [
        {
          id: '40623323541',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 42,
            login: 'yegor256',
            display_login: 'yegor256',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'yegor256',
                id: 42,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_142,
              number: 93
            }
          }
        },
        {
          id: '40623323542',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:46:09 UTC',
          actor: {
            id: 42,
            login: 'yegor256',
            display_login: 'yegor256',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegor256'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'yegor256',
                id: 42,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_142,
              number: 93
            }
          }
        },
        {
          id: '40623323550',
          type: 'PullRequestReviewEvent',
          public: true,
          created_at: '2024-07-31 12:45:09 UTC',
          actor: {
            id: 55,
            login: 'Yegorov',
            display_login: 'yegorov',
            gravatar_id: '',
            url: 'https://api.github.com/users/yegorov'
          },
          repo: {
            id: 42,
            name: 'yegor256/judges',
            url: 'https://api.github.com/repos/yegor256/judges'
          },
          payload: {
            action: 'created',
            review: {
              id: 2_210_067_609,
              node_id: 'PRR_kwDOL6GCO86DuvSZ',
              user: {
                login: 'yegorov',
                id: 42,
                node_id: 'MDQ6VXNlcjUyNjMwMQ==',
                type: 'User'
              },
              state: 'approved',
              pull_request_url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              _links: {
                html: {
                  href: 'https://github.com/yegor256/judges/pull/93#pullrequestreview-2210067609'
                },
                pull_request: {
                  href: 'https://api.github.com/repos/yegor256/judges/pulls/93'
                }
              }
            },
            pull_request: {
              url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
              id: 1_990_323_155,
              number: 93
            }
          }
        }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/55').to_return(
      body: { id: 55, login: 'torvalds' }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/pulls/93')
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
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(2, f.count)
    assert_equal(42, f.first.who)
    assert_equal(55, f.last.who)
    assert_equal(2, f.first.review_comments)
    assert_equal(2, f.last.review_comments)
  end

  def test_skip_pull_request_review_event_with_unknown_payload_action
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11124',
        type: 'PullRequestReviewEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'unknown',
          pull_request: { number: 123, head: { ref: '321', sha: 'a3b5a' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_124))
    assert(fb.none?(event_type: 'PullRequestReviewEvent'))
  end

  def test_release_event_contributors
    WebMock.disable_net_connect!
    rate_limit_up
    stub_event(
      {
        id: '1',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 820_463_873,
          name: 'zerocracy/fbe',
          url: 'https://api.github.com/repos/zerocracy/fbe'
        },
        payload: {
          action: 'published',
          release: {
            id: 123,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '0.0.1',
            created_at: '2024-08-05T00:51:39Z',
            published_at: '2024-08-05T00:52:07Z'
          }
        },
        public: true,
        created_at: '2024-08-05T00:52:08Z',
        org: {
          id: 24_234_201,
          login: 'zerocracy'
        }
      },
      {
        id: '5',
        type: 'ReleaseEvent',
        actor: {
          id: 8_086_956,
          login: 'rultor',
          display_login: 'rultor'
        },
        repo: {
          id: 820_463_873,
          name: 'zerocracy/fbe',
          url: 'https://api.github.com/repos/zerocracy/fbe'
        },
        payload: {
          action: 'published',
          release: {
            id: 124,
            author: {
              login: 'rultor',
              id: 8_086_956,
              type: 'User',
              site_admin: false
            },
            tag_name: '0.0.5',
            created_at: '2024-08-01T00:51:39Z',
            published_at: '2024-08-01T00:52:07Z'
          }
        },
        public: true,
        created_at: '2024-08-01T00:52:08Z',
        org: {
          id: 24_234_201,
          login: 'zerocracy'
        }
      }
    )
    stub_github(
      'https://api.github.com/repositories/820463873',
      body: { id: 820_463_873, name: 'fbe', full_name: 'zerocracy/fbe' }
    )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/fbe/contributors?per_page=100').to_return(
      body: [
        {
          login: 'yegor256',
          id: 526_301
        },
        {
          login: 'yegor512',
          id: 526_302
        }
      ].to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/user/8086956').to_return(
      body: {
        login: 'rultor',
        id: 8_086_956
      }.to_json, headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/fbe/commits?per_page=100').to_return(
      body: [
        { sha: '4683257342e98cd94becc2aa49900e720bd792e9' },
        { sha: '69a28ba1122af281936371bbb36f67e5b97246b1' }
      ].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(
      :get,
      'https://api.github.com/repos/zerocracy/fbe/commits?' \
      'per_page=100&sha=69a28ba1122af281936371bbb36f67e5b97246b1'
    ).to_return(
      body: [{ sha: '69a28ba1122af281936371bbb36f67e5b97246b1' }].to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )

    stub_request(
      :get,
      'https://api.github.com/repos/zerocracy/fbe/compare/' \
      '69a28ba1122af281936371bbb36f67e5b97246b1...0.0.1?per_page=100'
    ).to_return(
      body: {
        total_commits: 2,
        commits: [
          { sha: '4683257342e98cd94becc2aa49900e720bd792e9' },
          { sha: '69a28ba1122af281936371bbb36f67e5b97246b1' }
        ],
        files: [
          { additions: 5, deletions: 0, changes: 5 },
          { additions: 5, deletions: 5, changes: 10 },
          { additions: 0, deletions: 7, changes: 7 }
        ]
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/fbe/compare/0.0.1...0.0.5?per_page=100').to_return(
      body: {
        total_commits: 4,
        commits: [
          { sha: 'a50489ead5e8aa6', author: { login: 'Yegorov', id: 2_566_462 } },
          { sha: 'b50489ead5e8aa7', author: { login: 'Yegorov64', id: 2_566_463 } },
          { sha: 'c50489ead5e8aa8', author: { login: 'Yegorov128', id: 2_566_464 } },
          { sha: 'd50489ead5e8aa9', author: { login: 'Yegorov', id: 2_566_462 } },
          { sha: 'e50489ead5e8aa9', author: nil },
          { sha: 'e60489ead5e8aa9' },
          { sha: 'e70489ead5e8aa9', author: { login: 'NoUser' } }
        ],
        files: [
          { additions: 15, deletions: 40, changes: 55 },
          { additions: 20, deletions: 5, changes: 25 },
          { additions: 0, deletions: 10, changes: 10 }
        ]
      }.to_json,
      headers: {
        'Content-Type': 'application/json',
        'X-RateLimit-Remaining' => '999'
      }
    )
    fb = Factbase.new
    load_it('github-events', fb)
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
    WebMock.disable_net_connect!
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
    stub_github(
      'https://api.github.com/repos/foo/foo/releases/470000',
      body: {
        id: 470_000,
        tag_name: '0.0.2',
        target_commitish: 'master',
        name: 'v0.0.2',
        draft: false,
        prerelease: false,
        created_at: Time.parse('2024-08-02 21:45:00 UTC'),
        published_at: Time.parse('2024-08-02 21:45:00 UTC'),
        body: '0.0.2 release'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/0.0.2...0.0.3?per_page=100',
      body: {
        total_commits: 3,
        commits: [
          { sha: 'a50489ead5e8aa6', author: { login: 'Yegorov', id: 2_566_462 } },
          { sha: 'b50489ead5e8aa7', author: { login: 'Yegorov64', id: 2_566_463 } },
          { sha: '89ead5eb5048aa7', author: { login: 'Yegorov128', id: 2_566_464 } }
        ],
        files: [{ additions: 15, deletions: 40, changes: 55 }]
      }
    )
    stub_github(
      'https://api.github.com/user/8086956',
      body: { login: 'rultor', id: 8_086_956 }
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
    load_it('github-events', fb)
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_nil(f.first[:tag])
    refute_nil(f.first[:release_id])
    assert_equal([2_566_462, 2_566_463, 2_566_464], f.last[:contributors])
  end

  def test_release_event_contributors_without_last_release_tag_and_without_release_id
    WebMock.disable_net_connect!
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
    stub_github(
      'https://api.github.com/repos/foo/foo/contributors?per_page=100',
      body: [
        { login: 'yegor256', id: 526_301 },
        { login: 'yegor512', id: 526_302 }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits?per_page=100',
      body: [{ sha: '4683257342e98cd94' }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/4683257342e98cd94...0.0.3?per_page=100',
      body: {
        total_commits: 1,
        commits: [{ sha: 'a50489ead5e8aa6', author: { login: 'Yegorov', id: 2_566_462 } }],
        files: [{ additions: 15, deletions: 40, changes: 55 }]
      }
    )
    stub_github(
      'https://api.github.com/user/8086956',
      body: { login: 'rultor', id: 8_086_956 }
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
    load_it('github-events', fb)
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(2, f.count)
    assert_nil(f.first[:tag])
    assert_nil(f.first[:release_id])
    assert_equal([526_301, 526_302], f.last[:contributors])
  end

  def test_event_for_renamed_repository
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repositories/111/events?per_page=100',
      body: [
        {
          id: '4321000',
          type: 'ReleaseEvent',
          actor: {
            id: 29_139_614,
            login: 'renovate[bot]'
          },
          repo: {
            id: 111,
            name: 'foo/old_baz'
          },
          payload: {
            action: 'published',
            release: {
              id: 178_368,
              tag_name: 'v1.2.3',
              name: 'Release v1.2.3',
              author: {
                id: 29_139_614,
                login: 'renovate[bot]'
              }
            }
          },
          created_at: Time.parse('2024-11-01 12:30:15 UTC')
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/new_baz',
      body: { id: 111, name: 'new_baz', full_name: 'foo/new_baz' }
    )
    stub_github(
      'https://api.github.com/repositories/111',
      body: { id: 111, name: 'new_baz', full_name: 'foo/new_baz' }
    )
    stub_github(
      'https://api.github.com/user/29139614',
      body: {
        login: 'renovate[bot]',
        id: 29_139_614,
        type: 'Bot'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/new_baz/contributors?per_page=100',
      body: [
        {
          login: 'yegor256',
          id: 526_301
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/new_baz/releases/20000',
      body: {
        id: 20_000,
        tag_name: 'v1.2.2',
        target_commitish: 'master',
        name: 'Release v1.2.2',
        draft: false,
        prerelease: false,
        created_at: Time.parse('2024-10-31 21:45:00 UTC'),
        published_at: Time.parse('2024-10-31 21:45:00 UTC'),
        body: 'Release v1.2.2'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/new_baz/compare/v1.2.2...v1.2.3?per_page=100',
      body: {
        total_commits: 2,
        commits: [
          { sha: '2aa49900e720bd792e9' },
          { sha: '1bbb36f67e5b97246b1' }
        ],
        files: [
          { additions: 7, deletions: 4, changes: 11 },
          { additions: 2, deletions: 0, changes: 2 },
          { additions: 0, deletions: 7, changes: 7 }
        ]
      }
    )
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
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/new_baz' }))
    f = fb.query('(eq what "release-published")').each.to_a.last
    assert_equal(111, f.repository)
    assert_equal('v1.2.3', f.tag)
    refute_match(/old_baz/, f.details)
  end

  def test_skip_release_event_with_unknown_payload_action
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '55555', type: 'ReleaseEvent', actor: { id: 8_086_956, login: 'rultor' },
        repo: { id: 42, name: 'foo/foo', url: 'https://api.github.com/repos/foo/foo' },
        payload: { action: 'unknown', release: { id: 178_368, tag_name: '1.2.3' } },
        created_at: Time.parse('2025-06-27T00:52:08Z')
      }]
    )
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 55_555))
  end

  def test_pull_request_event_with_comments
    fb = Factbase.new
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'zerocracy/baza', 'testing' => true }))
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
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'zerocracy/baza', 'testing' => true }))
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 42))').each.first
    assert_equal(4, f.succeeded_builds)
    assert_equal(2, f.failed_builds)
  end

  def test_count_numbers_of_workflow_builds_only_from_github
    fb = Factbase.new
    load_it(
      'github-events',
      fb,
      Judges::Options.new({ 'repositories' => 'zerocracy/judges-action', 'testing' => true })
    )
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 43))').each.first
    assert_nil(f)
  end

  def test_no_have_access_to_resource_by_integration
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11111',
        type: 'PushEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: { push_id: 2412, ref: 'refs/heads/master', head: 'f5d59b035' },
        created_at: '2025-05-05 19:03:16 UTC'
      }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/f5d59b035/pulls?per_page=100',
      status: 403,
      body: {
        message: 'Resource not accessible by integration',
        documentation_url: 'https://docs.github.com/rest/commits/commits#list-pull-requests-associated-with-a-commit',
        status: '403'
      }
    )
    stub_github('https://api.github.com/user', body: { id: 123, login: 'GithubUser' })
    fb = Factbase.new
    ex =
      assert_raises(RuntimeError) do
        load_it('github-events', fb)
      end
    assert_equal("@GithubUser doesn't have access to the foo/foo repository, maybe it's private", ex.message)
    assert_equal(0, fb.size)
  end

  def test_no_have_access_to_resource_by_integration_in_handle_exception
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11111',
        type: 'PushEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: { push_id: 2412, ref: 'refs/heads/master', head: 'f5d59b035' },
        created_at: '2025-05-05 19:03:16 UTC'
      }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/f5d59b035/pulls?per_page=100',
      status: 403,
      body: {
        message: 'Resource not accessible by integration',
        documentation_url: 'https://docs.github.com/rest/commits/commits#list-pull-requests-associated-with-a-commit',
        status: '403'
      }
    )
    stub_github(
      'https://api.github.com/user',
      status: 403,
      body: {
        message: 'Resource not accessible by integration',
        documentation_url: 'https://docs.github.com/rest/users/users#get-the-authenticated-user',
        status: '403'
      }
    )
    fb = Factbase.new
    ex =
      assert_raises(RuntimeError) do
        load_it('github-events', fb)
      end
    assert_equal("You doesn't have access to the foo/foo repository, maybe it's private", ex.message)
    assert_equal(0, fb.size)
  end

  def test_skip_push_event_if_push_to_non_default_branch
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11111',
        type: 'PushEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: { push_id: 2412, ref: 'refs/heads/develop', head: 'f5d59b035' },
        created_at: '2025-06-26 19:25:00 UTC'
      }]
    )
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate'))
    assert(fb.none?(what: 'git-was-pushed'))
  end

  def test_success_add_push_event_to_factbase
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11111',
        type: 'PushEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: { push_id: 2412, ref: 'refs/heads/master', head: 'f5d59b035' },
        created_at: '2025-06-26 19:03:16 UTC'
      }]
    )
    stub_github('https://api.github.com/repos/foo/foo/commits/f5d59b035/pulls?per_page=100', body: [])
    stub_github('https://api.github.com/user/43', body: { id: 43, login: 'yegor256' })
    fb = Factbase.new
    load_it('github-events', fb)
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
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 100, name: 'foo', full_name: 'foo/foo', default_branch: 'master', owner: { id: 50, login: 'foo' } }
    )
    stub_github(
      'https://api.github.com/repositories/100',
      body: { id: 100, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/100/events?per_page=100',
      body: [{
        id: '22222',
        type: 'PushEvent',
        actor: { id: 50, login: 'foo' },
        repo: { id: 100, name: 'foo/foo' },
        payload: { push_id: 3000, ref: 'refs/heads/master', head: 'abc123def' },
        created_at: '2025-06-27 10:00:00 UTC'
      }]
    )
    stub_github('https://api.github.com/repos/foo/foo/commits/abc123def/pulls?per_page=100', body: [])
    stub_github('https://api.github.com/user/50', body: { id: 50, login: 'foo' })
    fb = Factbase.new
    load_it('github-events', fb)
    owner_push = fb.query('(and (eq what "git-was-pushed") (eq event_id 22222))').each.first
    refute_nil(owner_push)
    assert_equal(1, owner_push.by_owner)
    assert_equal(50, owner_push.who)
  end

  def test_push_event_by_non_owner_sets_by_owner_to_none
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 101, name: 'foo', full_name: 'foo/foo', default_branch: 'master', owner: { id: 50, login: 'foo' } }
    )
    stub_github(
      'https://api.github.com/repositories/101',
      body: { id: 101, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/repositories/101/events?per_page=100',
      body: [{
        id: '33333',
        type: 'PushEvent',
        actor: { id: 60, login: 'contributor' },
        repo: { id: 101, name: 'foo/foo' },
        payload: { push_id: 4000, ref: 'refs/heads/master', head: 'def456ghi' },
        created_at: '2025-06-27 11:00:00 UTC'
      }]
    )
    stub_github('https://api.github.com/repos/foo/foo/commits/def456ghi/pulls?per_page=100', body: [])
    stub_github('https://api.github.com/user/60', body: { id: 60, login: 'contributor' })
    fb = Factbase.new
    load_it('github-events', fb)
    contributor_push = fb.query('(and (eq what "git-was-pushed") (eq event_id 33333))').each.first
    refute_nil(contributor_push)
    assert_nil(contributor_push['by_owner'])
    assert_equal(60, contributor_push.who)
  end

  def test_success_add_opened_pull_request_event_to_factbase
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11122',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'opened', number: 456,
          pull_request: { number: 456, head: { ref: '487', sha: '5c955da3b5a' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    load_it('github-events', fb)
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
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11122',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'opened', number: 456,
          pull_request: { number: 456, head: { ref: '487', sha: '5c955da3b5a' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    fb.with(what: 'pull-was-opened', repository: 42, where: 'github', who: 45, issue: 456)
    load_it('github-events', fb)
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_122))
    assert(fb.one?(what: 'pull-was-opened', where: 'github', repository: 42, who: 45, issue: 456))
  end

  def test_skip_duplicate_opened_pull_request_event_without_who
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '55950772790',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'opened', number: 187,
          pull_request: { number: 187, head: { ref: 'fix-bug', sha: '5c955da3b5a' } }
        },
        created_at: '2025-10-16 19:00:00 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    fb.with(
      _id: 1, branch: 'fix-bug', details: 'The missing pull foo/foo#187 has been opened by @user.',
      issue: 187, repository: 42, what: 'pull-was-opened', when: '2025-10-16T19:00:00Z', where: 'github'
    )
    load_it('github-events', fb)
    assert(fb.one?(what: 'pull-was-opened', where: 'github', repository: 42, issue: 187))
  end

  def test_skip_pull_request_event_with_unknown_payload_action
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11123',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'unknown', number: 123,
          pull_request: { number: 123, head: { ref: '321', sha: 'a3b5a' } }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 11_123))
    assert(fb.none?(event_type: 'PullRequestEvent'))
  end

  def test_prevent_creation_of_duplicate_facts_upon_multiple_pr_closures
    WebMock.disable_net_connect!
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
    stub_github(
      'https://api.github.com/repos/bar/bar/pulls/305',
      body: {
        id: 50, number: 305, user: { id: 411, login: 'user' },
        head: { label: 'foo:origin/master', ref: 'origin/master', sha: '42b24481' },
        state: 'closed', title: 'some title', body: 'some body',
        created_at: Time.parse('2025-04-30 13:52:28 UTC'),
        updated_at: Time.parse('2025-05-03 11:36:34 UTC'),
        closed_at: Time.parse('2025-05-03 11:36:33 UTC'),
        merged_at: nil,
        author_association: 'CONTRIBUTOR',
        auto_merge: nil,
        active_lock_reason: nil,
        merged: false,
        mergeable: nil,
        rebaseable: nil,
        mergeable_state: 'unknown',
        merged_by: nil,
        comments: 3,
        review_comments: 0,
        maintainer_can_modify: false,
        commits: 1,
        additions: 2,
        deletions: 2,
        changed_files: 2
      }
    )
    stub_github('https://api.github.com/repos/bar/bar/pulls/305/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/bar/bar/pulls/305/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/bar/bar/issues/305/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/bar/bar/commits/42b24481/check-runs?per_page=100',
                body: { check_runs: [] })
    stub_github('https://api.github.com/user/411', body: { id: 411, login: 'user' })
    stub_github('https://api.github.com/repositories/43', body: { id: 43,  name: 'bar', full_name: 'bar/bar' })
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    assert_equal(1, fb.query('(eq what "pull-was-closed")').each.to_a.size)
  end

  def test_success_add_created_issue_comment_event_to_factbase
    skip('This type of event is not needed now')
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '22222',
        type: 'IssueCommentEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'created', issue: { number: 789 },
          comment: { id: 30_093, body: 'some text', user: { id: 43 } }
        },
        created_at: '2025-06-27 19:00:00 UTC'
      }]
    )
    stub_github('https://api.github.com/user/43', body: { id: 43, login: 'yegor256' })
    fb = Factbase.new
    load_it('github-events', fb)
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
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '22223',
        type: 'IssueCommentEvent',
        actor: { id: 43, login: 'yegor256' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'unknown', issue: { number: 789 },
          comment: { id: 30_093, body: 'some text', user: { id: 43 } }
        },
        created_at: '2025-06-27 19:00:00 UTC'
      }]
    )
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(1, fb.all.size)
    assert(fb.one?(what: 'iterate', repository: 42, events_were_scanned: 22_223))
    assert(fb.none?(event_type: 'IssueCommentEvent'))
  end

  def test_stop_scanning_if_number_event_greater_than_max_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'torvalds' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 14, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        },
        {
          id: 13, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        },
        {
          id: 12, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        },
        {
          id: 11, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        }
      ]
    )
    fb = Factbase.new
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'max_events' => 3 }))
    assert_equal(4, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 14))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 14))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 13))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 12))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 11))
  end

  def test_stop_scanning_if_event_id_less_or_eq_than_latest
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'torvalds' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 15, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        },
        {
          id: 14, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        },
        {
          id: 13, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, _time: Time.now.utc, where: 'github', repository: 42, events_were_scanned: 14, what: 'iterate')
    load_it('github-events', fb)
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 15))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 15))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 14))
    assert(fb.none?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 13))
  end

  def test_skip_fill_up_if_event_exists_in_factbase
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'torvalds' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 15, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(what: 'tag-was-created', event_type: 'CreateEvent', repository: 42, where: 'github', event_id: 15)
    load_it('github-events', fb)
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 15))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 15))
  end

  def test_empty_events
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/repositories/42/events?per_page=100', body: [])
    fb = Factbase.new
    load_it('github-events', fb)
    assert_equal(0, fb.all.size)
  end

  def test_finished_scanning_with_saving_latest_event_id
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/42', body: { id: 42, login: 'torvalds' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: 15, created_at: Time.now.to_s, actor: { id: 42 },
          type: 'CreateEvent', repo: { id: 42 },
          payload: { ref_type: 'tag', ref: 'foo' }
        }
      ]
    )
    fb = Factbase.new
    fb.with(_id: 1, _time: Time.now.utc, where: 'github', repository: 42, events_were_scanned: 12, what: 'iterate')
    load_it('github-events', fb)
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 15))
    assert(fb.one?(what: 'tag-was-created', where: 'github', event_type: 'CreateEvent', repository: 42, event_id: 15))
  end

  def test_handle_pull_request_event_with_old_repo_name
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user1' })
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: '11122',
          type: 'PullRequestEvent',
          actor: { id: 45, login: 'user' },
          repo: { id: 42, name: 'foo/old_foo' },
          payload: {
            action: 'closed',
            number: 456,
            pull_request: {
              number: 456,
              head: { ref: '487', sha: '5c955da3b5a' },
              base: {
                ref: 'master',
                sha: 'e38d0ec',
                repo: {
                  id: 42,
                  name: 'old_foo'
                }
              }
            }
          },
          created_at: '2025-06-27 19:00:05 UTC'
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/456',
      body: {
        id: 50, number: 456, user: { id: 46, login: 'user2' },
        head: { ref: '487', sha: '5c955da3b5a' },
        additions: 1, deletions: 1
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/456/reviews?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/old_foo/issues/456/comments?per_page=100',
      status: 302,
      body: {
        message: 'Moved Permanently',
        url: 'https://api.github.com/repositories/42/issues/456/comments?per_page=100',
        documentation_url: 'https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api#follow-redirects'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/old_foo/pulls/456/comments?per_page=100',
      status: 302,
      body: {
        message: 'Moved Permanently',
        url: 'https://api.github.com/repositories/42/pulls/456/comments?per_page=100',
        documentation_url: 'https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api#follow-redirects'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/456/comments?per_page=100',
      body: [{ pull_request_review_id: 291, id: 213, user: { login: 'user123', id: 123 } }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/456/comments?per_page=100',
      body: [{ id: 313, user: { login: 'user123', id: 123 } }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/issues/comments/313/reactions',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/comments/213/reactions',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/old_foo/commits/5c955da3b5a/check-runs?per_page=100',
      status: 302,
      body: {
        message: 'Moved Permanently',
        url: 'https://api.github.com/repositories/42/commits/5c955da3b5a/check-runs?per_page=100',
        documentation_url: 'https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api#follow-redirects'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits/5c955da3b5a/check-runs?per_page=100',
      body: { check_runs: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    assert_equal(2, fb.all.size)
    assert(fb.one?(what: 'iterate', where: 'github', repository: 42, events_were_scanned: 11_122))
    assert(fb.one?(what: 'pull-was-closed', where: 'github', repository: 42, issue: 456))
  end

  def test_pull_request_event_captures_changed_files
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [{
        id: '11126',
        type: 'PullRequestEvent',
        actor: { id: 45, login: 'user' },
        repo: { id: 42, name: 'foo/foo' },
        payload: {
          action: 'closed',
          number: 123,
          pull_request: {
            number: 123,
            head: { ref: 'feature-branch', sha: 'abc123' }
          }
        },
        created_at: '2025-06-27 19:00:05 UTC'
      }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123',
      body: {
        id: 50, number: 123, user: { id: 46, login: 'user2' },
        head: { ref: 'feature-branch', sha: 'abc123' },
        merged: true, state: 'closed', merged_at: Time.parse('2025-06-27 19:00:05 UTC'),
        additions: 10, deletions: 5, changed_files: 7
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/abc123/check-runs?per_page=100', body: { check_runs: [] })
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-merged")').each.first
    refute_nil(f)
    assert_equal(7, f.files)
    assert_equal(15, f.hoc)
  end

  def test_closed_pull_request_event_with_nil_additions_or_deletions
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: '11126',
          type: 'PullRequestEvent',
          actor: { id: 45, login: 'user' },
          repo: { id: 42, name: 'foo/foo' },
          payload: {
            action: 'closed',
            number: 123,
            pull_request: {
              number: 123,
              head: { ref: 'feature-branch', sha: 'abc123' }
            }
          },
          created_at: '2025-06-27 19:00:05 UTC'
        },
        {
          id: '11125',
          type: 'PullRequestEvent',
          actor: { id: 45, login: 'user' },
          repo: { id: 42, name: 'foo/foo' },
          payload: {
            action: 'closed',
            number: 122,
            pull_request: {
              number: 122,
              head: { ref: 'feature-branch', sha: 'abc123' }
            }
          },
          created_at: '2025-06-26 19:00:05 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123',
      body: {
        id: 50, number: 123, user: { id: 46, login: 'user2' },
        merged: true, state: 'closed', merged_at: Time.parse('2025-06-27 19:00:05 UTC'),
        head: { ref: 'feature-branch', sha: 'abc123' },
        additions: nil, deletions: 5, changed_files: 7
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/122',
      body: {
        id: 51, number: 122, user: { id: 46, login: 'user2' },
        merged: true, state: 'closed', merged_at: Time.parse('2025-06-26 19:00:05 UTC'),
        head: { ref: 'feature-branch', sha: 'abc123' },
        additions: 7, deletions: nil, changed_files: 7
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/122/reviews?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/pulls/122/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/122/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/abc123/check-runs?per_page=100', body: { check_runs: [] })
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    f1, f2 = fb.query('(eq what "pull-was-merged")').each.to_a
    refute_nil(f1)
    assert_equal(5, f1.hoc)
    refute_nil(f2)
    assert_equal(7, f2.hoc)
  end

  def test_closed_pull_request_with_exist_review_and_code_suggestions
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42',
      body: { id: 42, name: 'foo', full_name: 'foo/foo', default_branch: 'master' }
    )
    stub_github(
      'https://api.github.com/repositories/42/events?per_page=100',
      body: [
        {
          id: '11126',
          type: 'PullRequestEvent',
          actor: { id: 45, login: 'user' },
          repo: { id: 42, name: 'foo/foo' },
          payload: {
            action: 'closed',
            number: 123,
            pull_request: {
              number: 123,
              head: { ref: 'feature-branch', sha: 'abc123' }
            }
          },
          created_at: '2025-10-20 19:00:05 UTC'
        }
      ]
    )
    stub_github('https://api.github.com/user/45', body: { id: 45, login: 'user' })
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123',
      body: {
        id: 50, number: 123, user: { id: 45, login: 'user' },
        head: { ref: 'feature-branch', sha: 'abc123' },
        merged: true, state: 'closed', merged_at: Time.parse('2025-10-20 19:00:05 UTC'),
        additions: nil, deletions: 5, changed_files: 7
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123/reviews?per_page=100',
      body: [
        { id: 123, user: { id: 46, login: 'user2' }, body: 'Great!', submitted_at: '2025-10-20 18:05:00 UTC' },
        { id: 124, user: { id: 45, login: 'user' }, body: '', submitted_at: '2025-10-20 18:25:00 UTC' }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123/reviews/123/comments?per_page=100',
      body: [
        {
          id: 22_100, pull_request_review_id: 123,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func1...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some question1', created_at: '2025-10-20 18:06:00 UTC', user: { id: 46, login: 'user2' }
        },
        {
          id: 22_101, pull_request_review_id: 123,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func2...', path: 'lib/some/path/file2.rb', commit_id: '3e695',
          body: 'Some question2', created_at: '2025-10-20 18:07:00 UTC', user: { id: 46, login: 'user2' }
        }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/pulls/123/reviews/124/comments?per_page=100',
      body: [
        {
          id: 22_103, pull_request_review_id: 124,
          diff_hunk: '@@ -93,4 +93,65 @@ def some_func...', path: 'lib/some/path/file1.rb', commit_id: '3e695',
          body: 'Some answer1', created_at: '2025-10-20 15:25:00 UTC', user: { id: 45, login: 'user' },
          in_reply_to_id: 22_100
        }
      ]
    )
    stub_github('https://api.github.com/repos/foo/foo/pulls/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/issues/123/comments?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/foo/commits/abc123/check-runs?per_page=100', body: { check_runs: [] })
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('github-events', fb)
    end
    f = fb.query('(eq what "pull-was-merged")').each.to_a.first
    refute_nil(f)
    assert_equal(Time.parse('2025-10-20 18:05:00 UTC'), f.review)
    assert_equal(2, f.suggestions)
  end

  def test_release_event_with_nil_compare_response
    WebMock.disable_net_connect!
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
    stub_github(
      'https://api.github.com/repos/foo/foo/contributors?per_page=100',
      body: [{ login: 'yegor256', id: 526_301 }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/commits?per_page=100',
      body: [{ sha: 'abc123def456' }]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/compare/abc123def456...1.0.0?per_page=100',
      status: 404,
      body: {
        message: 'Not Found',
        documentation_url: 'https://docs.github.com/rest/commits/commits#compare-two-commits',
        status: '404'
      }
    )
    stub_github(
      'https://api.github.com/user/8086956',
      body: { login: 'rultor', id: 8_086_956 }
    )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(and (eq repository 42) (eq what "release-published"))').each.to_a
    assert_equal(1, f.count)
    assert_equal([526_301], f.first[:contributors])
  end

  def test_write_supervision_log_if_raise_error
    WebMock.disable_net_connect!
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
      load_it('github-events', Factbase.new, loog:)
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
