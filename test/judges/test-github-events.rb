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
    assert_equal(42, f[1].who)
  end

  private

  def stub_event(json)
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
      body: [json].to_json,
      headers: {
        'content-type': 'application/json'
      }
    )
  end
end
