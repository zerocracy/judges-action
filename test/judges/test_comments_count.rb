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

require 'fbe/octo'
require 'factbase'
require 'loog'
require 'json'
require 'minitest/autorun'
require 'webmock/minitest'
require 'judges/options'
require_relative '../../lib/judges/comments'

class TestJudgesComments < Minitest::Test
  def test_counts_comments
    WebMock.disable_net_connect!
    init_fb(Factbase.new)
    stub_comments
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/issues/comments/1709082320/reactions')
      .to_return(
        status: 200,
        body: [
          {
            id: 248_923_574,
            user: {
              login: 'rultor',
              id: 8_086_956
            },
            content: 'heart'
          }
        ]
      )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/issues/comments/1709082321/reactions')
      .to_return(
        status: 200,
        body: [
          {
            id: 248_923_574,
            user: {
              login: 'rultor',
              id: 8_086_956
            },
            content: 'heart'
          },
          {
            id: 248_923_575,
            user: {
              login: 'test',
              id: 88_084_038
            },
            content: 'heart'
          }
        ]
      )
    pull_request = {
      url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
      id: 1_990_323_142,
      node_id: 'PR_kwDOL6GCO852oevG',
      number: 172,
      state: 'closed',
      locked: false,
      title: '#999 new feature',
      user: {
        login: 'test',
        id: 88_084_038,
        node_id: 'MDQ6VXNlcjE2NDYwMjA=',
        type: 'User',
        site_admin: false
      },
      base: {
        label: 'zerocracy:master',
        ref: 'master',
        user: {
          login: 'zerocracy',
          id: 24_234_201
        },
        repo: {
          id: 728_758_275,
          node_id: 'R_kgDOK2_4Aw',
          name: 'baza',
          full_name: 'zerocracy/baza',
          private: false
        }
      },
      comments: 2,
      review_comments: 2,
      commits: 1,
      additions: 3,
      deletions: 3,
      changed_files: 2
    }
    comments = Judges::Comments.new(octo: Fbe.octo, pull_request:)
    assert_equal(4, comments.total)
    assert_equal(2, comments.to_code)
    assert_equal(1, comments.by_author)
    assert_equal(1, comments.by_reviewers)
    assert_equal(2, comments.appreciated)
  end

  def test_counts_comments_without_reactions
    WebMock.disable_net_connect!
    init_fb(Factbase.new)
    stub_comments
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/issues/comments/1709082320/reactions')
      .to_return(
        status: 200,
        body: []
      )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/issues/comments/1709082321/reactions')
      .to_return(
        status: 200,
        body: []
      )
    pull_request = {
      url: 'https://api.github.com/repos/yegor256/judges/pulls/93',
      id: 1_990_323_142,
      node_id: 'PR_kwDOL6GCO852oevG',
      number: 172,
      state: 'closed',
      locked: false,
      title: '#999 new feature',
      user: {
        login: 'test',
        id: 88_084_038,
        node_id: 'MDQ6VXNlcjE2NDYwMjA=',
        type: 'User',
        site_admin: false
      },
      base: {
        label: 'zerocracy:master',
        ref: 'master',
        user: {
          login: 'zerocracy',
          id: 24_234_201
        },
        repo: {
          id: 728_758_275,
          node_id: 'R_kgDOK2_4Aw',
          name: 'baza',
          full_name: 'zerocracy/baza',
          private: false
        }
      },
      comments: 2,
      review_comments: 2,
      commits: 1,
      additions: 3,
      deletions: 3,
      changed_files: 2
    }
    comments = Judges::Comments.new(octo: Fbe.octo, pull_request:)
    assert_equal(4, comments.total)
    assert_equal(2, comments.to_code)
    assert_equal(1, comments.by_author)
    assert_equal(1, comments.by_reviewers)
    assert_equal(0, comments.appreciated)
  end

  private

  def stub_comments
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/pulls/172/comments?per_page=100')
      .to_return(
        status: 200,
        body: [
          {
            pull_request_review_id: 2_227_372_510,
            id: 1_709_082_318,
            path: 'test/baza/test_locks.rb',
            commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
            original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
            user: {
              login: 'Reviewer',
              id: 2_566_462
            },
            body: 'Most likely, parentheses were missed here.',
            created_at: '2024-08-08T09:41:46Z',
            updated_at: '2024-08-08T09:42:46Z',
            reactions: {
              url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082318/reactions',
              total_count: 0
            },
            start_line: 'null',
            original_start_line: 'null',
            start_side: 'null',
            line: 'null',
            original_line: 62,
            side: 'RIGHT',
            original_position: 25,
            position: 'null',
            subject_type: 'line'
          },
          {
            pull_request_review_id: 2_227_372_510,
            id: 1_709_082_319,
            path: 'test/baza/test_locks.rb',
            commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
            original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
            user: {
              login: 'test',
              id: 88_084_038
            },
            body: 'definitely a typo',
            created_at: '2024-08-08T09:42:46Z',
            updated_at: '2024-08-08T09:42:46Z',
            reactions: {
              url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082319/reactions',
              total_count: 0
            },
            start_line: 'null',
            original_start_line: 'null',
            start_side: 'null',
            line: 'null',
            original_line: 62,
            side: 'RIGHT',
            original_position: 25,
            in_reply_to_id: 1_709_082_318,
            position: 'null',
            subject_type: 'line'
          }
        ]
      )
    stub_request(:get, 'https://api.github.com/repos/zerocracy/baza/issues/172/comments?per_page=100')
      .to_return(
        status: 200,
        body: [
          {
            pull_request_review_id: 2_227_372_510,
            id: 1_709_082_320,
            path: 'test/baza/test_locks.rb',
            commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
            original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
            user: {
              login: 'Reviewer',
              id: 2_566_462
            },
            body: 'reviewer comment',
            created_at: '2024-08-08T09:41:46Z',
            updated_at: '2024-08-08T09:42:46Z',
            reactions: {
              url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082320/reactions',
              total_count: 1
            },
            start_line: 'null',
            original_start_line: 'null',
            start_side: 'null',
            line: 'null',
            original_line: 62,
            side: 'RIGHT',
            original_position: 25,
            position: 'null',
            subject_type: 'line'
          },
          {
            pull_request_review_id: 2_227_372_510,
            id: 1_709_082_321,
            path: 'test/baza/test_locks.rb',
            commit_id: 'a9f5f94cf28f29a64d5dd96d0ee23b4174572847',
            original_commit_id: 'e8c6f94274d14ed3cb26fe71467a9c3f229df59c',
            user: {
              login: 'test',
              id: 88_084_038
            },
            body: 'author comment',
            created_at: '2024-08-08T09:42:46Z',
            updated_at: '2024-08-08T09:42:46Z',
            reactions: {
              url: 'https://api.github.com/repos/zerocracy/baza/pulls/comments/1709082321/reactions',
              total_count: 1
            },
            start_line: 'null',
            original_start_line: 'null',
            start_side: 'null',
            line: 'null',
            original_line: 62,
            side: 'RIGHT',
            original_position: 25,
            in_reply_to_id: 1_709_082_318,
            position: 'null',
            subject_type: 'line'
          }
        ]
      )
  end
end
