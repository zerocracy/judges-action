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

require 'obk'
require 'octokit'

def octo
  $global[:octo] ||= begin
    if $options.testing.nil?
      o = Octokit::Client.new
      token = $options.token
      $loog.debug("The 'token' option is not provided") if token.nil?
      token = ENV.fetch('GITHUB_TOKEN', nil) if token.nil?
      $loog.debug("The 'GITHUB_TOKEN' environment variable is not set") if token.nil?
      if token.nil?
        $loog.warn('Accessing GitHub API without a token!')
      else
        o = Octokit::Client.new(access_token: token)
        $loog.info("Accessing GitHub API with a token (#{token.length} chars)")
      end
      o = Obk.new(o, pause: 1000)
    else
      $loog.debug('The connection to GitHub API is mocked')
      o = FakeOctokit.new
    end
    def o.off_quota
      left = rate_limit.remaining
      if left < 5
        $loog.info("To much GitHub API quota consumed already (remaining=#{left}), stopping")
        true
      else
        false
      end
    end
    def o.user_name_by_id(id)
      json = user(id)
      name = json[:login]
      $loog.debug("GitHub user ##{id} has a name: @#{name}")
      name
    end
    def o.repo_id_by_name(name)
      json = repository(name)
      id = json[:id]
      $loog.debug("GitHub repository #{id} has an ID: #{id}")
      id
    end
    def o.through_pages(*args)
      m = args.shift
      page = 1
      catch :break do
        loop do
          r = send(m, *(args + [{ page: }]))
          break if r.empty?
          r.each do |json|
            yield json
          end
          page += 1
        end
      end
    end
    o
  end
  $global[:octo]
end

# Fake GitHub client, for tests.
class FakeOctokit
  def rate_limit
    o = Object.new
    def o.remaining
      100
    end
    o
  end

  def repositories(_user = nil)
    [
      {
        name: 'judges',
        full_name: 'yegor256/judges',
        id: 444
      }
    ]
  end

  def user(name)
    {
      id: 444,
      login: 'yegor256'
    }
  end

  def repository(name)
    {
      id: 444,
      full_name: name
    }
  end

  def add_comment(_repo, _issue, _text)
    42
  end

  def search_issues(_query, _options = {})
    {
      items: [
        {
          number: 42,
          labels: [
            {
              name: 'bug'
            }
          ]
        }
      ]
    }
  end

  def issue_timeline(_repo, _issue, _options = {})
    [
      {
        actor: {
          id: 888,
          name: 'torvalds'
        },
        repository: {
          id: 888,
          full_name: 'yegor256/judges'
        },
        event: 'labeled',
        label: {
          name: 'bug'
        },
        created_at: Time.now
      }
    ]
  end

  def repository_events(repo, _options = {})
    [
      {
        id: 123,
        repo: {
          id: 42,
          name: repo
        },
        type: 'PushEvent',
        payload: {
          push_id: 42
        },
        actor: {
          id: 888,
          name: 'torvalds'
        },
        created_at: Time.now
      },
      {
        id: 124,
        repo: {
          id: 42,
          name: repo
        },
        type: 'IssuesEvent',
        payload: {
          action: 'closed',
          issue: {
            number: 42
          }
        },
        actor: {
          id: 888,
          name: 'torvalds'
        },
        created_at: Time.now
      },
      {
        id: 125,
        repo: {
          id: 42,
          name: repo
        },
        type: 'IssuesEvent',
        payload: {
          action: 'opened',
          issue: {
            number: 42
          }
        },
        actor: {
          id: 888,
          name: 'torvalds'
        },
        created_at: Time.now
      }
    ]
  end
end
