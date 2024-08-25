# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'factbase'
require 'loog'
require 'json'
require 'minitest/autorun'
require 'webmock/minitest'
require 'judges/options'
require 'fbe'
require 'fbe/github_graph'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestGithubEvents < Minitest::Test
  def test_create_tag_event
    WebMock.disable_net_connect!
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
        'content-type': 'application/json'
      }
    )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(eq what "tag-was-created")').each.to_a.first
    assert_equal(42, f.who)
    assert_equal('foo', f.tag)
  end

  def test_skip_watch_event
    WebMock.disable_net_connect!
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
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
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
              author_association: 'OWNER',
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
              node_id: 'PR_kwDOL6GCO852oevG',
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjE2NDYwMjA=',
                type: 'User',
                site_admin: false
              }
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
              author_association: 'NONE',
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
              node_id: 'PR_kwDOL6GCO852oevG',
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjE2NDYwMjA=',
                type: 'User',
                site_admin: false
              }
            }
          }
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/526200').to_return(
      body: { id: 526_200, login: 'test' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/pulls/93')
      .to_return(
        status: 200,
        body: {
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: { 'content-type': 'application/json' }
      )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(42, f.first.who)
    assert_nil(f[1])
  end

  def test_add_only_approved_pull_request_review_events
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
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
              state: 'approved',
              author_association: 'OWNER'
            },
            pull_request: {
              id: 1_990_323_142,
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                type: 'User',
                site_admin: false
              }
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
              state: 'commented',
              author_association: 'NONE'
            },
            pull_request: {
              id: 1_990_323_142,
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                type: 'User',
                site_admin: false
              }
            }
          }
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/43').to_return(
      body: { id: 43, login: 'yegor256' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/526200').to_return(
      body: { id: 526_200, login: 'test' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/pulls/93')
      .to_return(
        status: 200,
        body: {
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: { 'content-type': 'application/json' }
      )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(1, f.count)
    assert_equal(42, f.first.who)
  end

  def test_skip_issue_was_opened_event
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
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
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/issues/1347').to_return(
      status: 200,
      body: { number: 1347, state: 'open' }.to_json,
      headers: { 'content-type': 'application/json' }
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
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
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
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/issues/1347').to_return(
      status: 200,
      body: { number: 1347, state: 'closed' }.to_json,
      headers: { 'content-type': 'application/json' }
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

  def test_watch_pull_request_review_events
    WebMock.disable_net_connect!
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
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
              author_association: 'OWNER',
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
              node_id: 'PR_kwDOL6GCO852oevG',
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjE2NDYwMjA=',
                type: 'User',
                site_admin: false
              }
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
              author_association: 'OWNER',
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
              node_id: 'PR_kwDOL6GCO852oevG',
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjE2NDYwMjA=',
                type: 'User',
                site_admin: false
              }
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
              author_association: 'OWNER',
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
              node_id: 'PR_kwDOL6GCO852oevG',
              number: 93,
              state: 'open',
              locked: false,
              title: 'allows to push gizpped factbase',
              user: {
                login: 'test',
                id: 526_200,
                node_id: 'MDQ6VXNlcjE2NDYwMjA=',
                type: 'User',
                site_admin: false
              }
            }
          }
        }
      ].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/42').to_return(
      body: { id: 42, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/55').to_return(
      body: { id: 55, login: 'torvalds' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/yegor256/judges/pulls/93')
      .to_return(
        status: 200,
        body: {
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: 2,
          commits: 2,
          changed_files: 3
        }.to_json,
        headers: { 'content-type': 'application/json' }
      )
    fb = Factbase.new
    load_it('github-events', fb)
    f = fb.query('(eq what "pull-was-reviewed")').each.to_a
    assert_equal(2, f.count)
    assert_equal(42, f.first.who)
    assert_equal(55, f.last.who)
  end

  def test_release_event_contributors
    WebMock.disable_net_connect!
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
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/user/8086956').to_return(
      body: {
        login: 'rultor',
        id: 8_086_956
      }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/fbe/commits?per_page=100').to_return(
      body: [
        { sha: '4683257342e98cd94becc2aa49900e720bd792e9' },
        { sha: '69a28ba1122af281936371bbb36f67e5b97246b1' }
      ].to_json,
      headers: { 'content-type': 'application/json' }
    )
    stub_request(
      :get,
      'https://api.github.com/repos/zerocracy/fbe/commits?' \
      'per_page=100&sha=69a28ba1122af281936371bbb36f67e5b97246b1'
    ).to_return(
      body: [{ sha: '69a28ba1122af281936371bbb36f67e5b97246b1' }].to_json,
      headers: { 'content-type': 'application/json' }
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
      headers: { 'content-type': 'application/json' }
    )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/fbe/compare/0.0.1...0.0.5?per_page=100').to_return(
      body: {
        total_commits: 4,
        commits: [
          { sha: 'a50489ead5e8aa6', author: { login: 'Yegorov', id: 2_566_462 } },
          { sha: 'b50489ead5e8aa7', author: { login: 'Yegorov64', id: 2_566_463 } },
          { sha: 'c50489ead5e8aa8', author: { login: 'Yegorov128', id: 2_566_464 } },
          { sha: 'd50489ead5e8aa9', author: { login: 'Yegorov', id: 2_566_462 } }
        ],
        files: [
          { additions: 15, deletions: 40, changes: 55 },
          { additions: 20, deletions: 5, changes: 25 },
          { additions: 0, deletions: 10, changes: 10 }
        ]
      }.to_json,
      headers: { 'content-type': 'application/json' }
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

  def test_pull_request_event_with_comments
    fb = Factbase.new
    load_it('github-events', fb, Judges::Options.new({ 'repositories' => 'zerocracy/baza', 'testing' => true }))
    f = fb.query('(eq what "pull-was-merged")').each.to_a.first
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
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 42))').each.to_a.first
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
    f = fb.query('(and (eq what "pull-was-merged") (eq event_id 43))').each.to_a.first
    assert_equal(3, f.succeeded_builds)
    assert_equal(2, f.failed_builds)
  end

  private

  def stub_event(*json)
    stub_request(:get, 'https://api.github.com/repos/foo/foo').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42').to_return(
      body: { id: 42, full_name: 'foo/foo' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repositories/42/events?per_page=100').to_return(
      body: json.to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
  end
end
