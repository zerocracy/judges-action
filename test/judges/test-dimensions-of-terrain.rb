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
class TestDimensionsOfTerrain < Minitest::Test
  def test_total_repositories
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 8,
        forks: 5,
        default_branch: 'master',
        archived: false
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/bar',
      body: {
        name: 'bar',
        full_name: 'foo/bar',
        private: false,
        created_at: Time.parse('2024-07-08 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-22 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-22 20:22:51 UTC'),
        size: 20_065,
        stargazers_count: 9,
        forks: 3,
        default_branch: 'master',
        archived: false
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/qwe',
      body: {
        name: 'qwe',
        full_name: 'foo/qwe',
        private: false,
        created_at: Time.parse('2024-07-06 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-22 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-21 20:22:51 UTC'),
        size: 15_387,
        stargazers_count: 3,
        forks: 4,
        default_branch: 'master',
        archived: true
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/asd',
      body: {
        name: 'asd',
        full_name: 'foo/asd',
        private: false,
        created_at: Time.parse('2024-07-05 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-27 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-20 20:22:51 UTC'),
        size: 25_741,
        stargazers_count: 9,
        forks: 12,
        default_branch: 'master',
        archived: false
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/releases?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/bar/releases?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/qwe/releases?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/asd/releases?per_page=100', body: [])
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: { sha: 'abc012340f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/bar/git/trees/master?recursive=true',
      body: { sha: 'abc012341f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/qwe/git/trees/master?recursive=true',
      body: { sha: 'abc012342f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/asd/git/trees/master?recursive=true',
      body: { sha: 'abc012343f', tree: [], truncated: false }
    )
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/bar/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/qwe/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/asd/contributors?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/bar%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/qwe%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/asd%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb,
                Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar,foo/qwe,foo/asd' }))
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal('dimensions-of-terrain', f.what)
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(3, f.total_repositories)
      end
    end
  end

  def test_total_releases
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 1,
        forks: 1,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: [
        { id: 50, tag_name: '0.0.9', draft: false, published_at: Time.parse('2024-08-22 21:00:00 UTC') },
        { id: 44, tag_name: '0.0.8', draft: false, published_at: Time.parse('2024-08-19 21:00:00 UTC') },
        { id: 32, tag_name: '0.0.7', draft: false, published_at: Time.parse('2024-08-15 21:00:00 UTC') },
        { id: 25, tag_name: '0.0.6', draft: false, published_at: Time.parse('2024-08-14 21:00:00 UTC') },
        { id: 18, tag_name: '0.0.5', draft: false, published_at: Time.parse('2024-08-12 21:00:00 UTC') },
        { id: 12, tag_name: '0.0.4', draft: true, published_at: Time.parse('2024-08-10 21:00:00 UTC') },
        { id: 5, tag_name: '0.0.3', draft: false, published_at: nil },
        { id: 3, tag_name: '0.0.2', draft: false, published_at: Time.parse('2024-08-03 21:00:00 UTC') },
        { id: 1, tag_name: '0.0.1', draft: false, published_at: Time.parse('2024-07-25 21:00:00 UTC') }
      ]
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: { sha: 'abc012345f', tree: [], truncated: false }
    )
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb)
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(9, f.total_releases)
      end
    end
  end

  def test_total_stars_and_forks
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 12,
        forks: 8,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/bar',
      body: {
        name: 'bar',
        full_name: 'foo/bar',
        private: false,
        created_at: Time.parse('2024-07-08 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-22 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-22 20:22:51 UTC'),
        size: 20_065,
        stargazers_count: 8,
        forks: 7,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/bar/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: { sha: 'abc012345f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/bar/git/trees/master?recursive=true',
      body: { sha: 'abc012346f', tree: [], truncated: false }
    )
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github('https://api.github.com/repos/foo/bar/contributors?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/bar%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo,foo/bar' }))
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal(Time.parse('2024-09-29 21:00:00 UTC'), f.when)
        assert_equal(20, f.total_stars)
        assert_equal(15, f.total_forks)
      end
    end
  end

  def test_total_issues_and_pull_requests
    WebMock.disable_net_connect!
    fb = Factbase.new
    load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'testing' => true }))
    f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
    assert_equal(23, f.total_issues)
    assert_equal(19, f.total_pulls)
  end

  def test_total_commits
    WebMock.disable_net_connect!
    fb = Factbase.new
    load_it('dimensions-of-terrain', fb,
            Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo', 'testing' => true }))
    f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
    assert_equal(1484, f.total_commits)
  end

  def test_total_files
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 1,
        forks: 1,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/yegor256/empty-repo',
      body: {
        name: 'yegor256',
        full_name: 'yegor256/empty-repo',
        private: false,
        created_at: Time.parse('2024-07-10 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-22 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-22 20:22:51 UTC'),
        size: 0,
        stargazers_count: 0,
        forks: 0,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/yegor256/empty-repo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: {
        sha: '492072971ad3c8644a191f',
        tree: [
          {
            path: '.github',
            mode: '040000',
            type: 'tree',
            sha: '438682e07e45ccbf9ca58f294a'
          },
          {
            path: '.github/workflows',
            mode: '040000',
            type: 'tree',
            sha: 'dea8a01c236530cc92a63c5774'
          },
          {
            path: '.github/workflows/actionlint.yml',
            mode: '100644',
            type: 'blob',
            sha: 'ffed2deef2383d6f685489b289',
            size: 1671
          },
          {
            path: '.github/workflows/copyrights.yml',
            mode: '100644',
            type: 'blob',
            sha: 'ab8357cfd94e0628676aff34cd',
            size: 1293
          },
          {
            path: '.github/workflows/zerocracy.yml',
            mode: '100644',
            type: 'blob',
            sha: '5c224c7742e5ebeeb176b90605',
            size: 2005
          },
          {
            path: '.gitignore',
            mode: '100644',
            type: 'blob',
            sha: '9383e7111a173b44baa0692775',
            size: 27
          },
          {
            path: '.rubocop.yml',
            mode: '100644',
            type: 'blob',
            sha: 'cb9b62eb1979589daa18142008',
            size: 1963
          },
          {
            path: 'README.md',
            mode: '100644',
            type: 'blob',
            sha: '8011ad43c37edbaf1969417b94',
            size: 4877
          },
          {
            path: 'Rakefile',
            mode: '100644',
            type: 'blob',
            sha: 'a0ac9bf2643d9f5392e1119301',
            size: 1805
          }
        ],
        truncated: false
      }
    )
    stub_github('https://api.github.com/repos/foo/foo/contributors?per_page=100', body: [])
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:yegor256/empty-repo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb,
                Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo' }))
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal(7, f.total_files)
      end
    end
  end

  def test_total_contributors
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 1,
        forks: 1,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/yegor256/empty-repo',
      body: {
        name: 'yegor256',
        full_name: 'yegor256/empty-repo',
        private: false,
        created_at: Time.parse('2024-07-10 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-22 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-22 20:22:51 UTC'),
        size: 0,
        stargazers_count: 0,
        forks: 0,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/yegor256/empty-repo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: { sha: 'abc012345f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/contributors?per_page=100',
      body: [
        { login: 'yegor256', id: 526_301, type: 'User', contributions: 500 },
        { login: 'renovate[bot]', id: 29_139_614, type: 'Bot', contributions: 320 },
        { login: 'user1', id: 2_476_362, type: 'User', contributions: 120 },
        { login: 'rultor', id: 8_086_956, type: 'Bot', contributions: 87 },
        { login: 'user2', id: 1_455_229, type: 'User', contributions: 65 },
        { login: 'user3', id: 3_411_938, type: 'User', contributions: 45 },
        { login: 'bot1', id: 4_122_600, type: 'Bot', contributions: 40 },
        { login: 'user4', id: 2_117_778, type: 'User', contributions: 32 },
        { login: 'user5', id: 5_427_638, type: 'User', contributions: 25 },
        { login: 'user6', id: 2_648_875, type: 'User', contributions: 10 },
        { login: 'user7', id: 7_125_293, type: 'User', contributions: 1 },
        { login: 'bot2', id: 4_199_655, type: 'Bot', contributions: 1 }
      ]
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:yegor256/empty-repo%20author-date:%3E2024-08-30',
      body: { total_count: 0, incomplete_results: false, items: [] }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb,
                Judges::Options.new({ 'repositories' => 'foo/foo,yegor256/empty-repo' }))
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal(12, f.total_contributors)
      end
    end
  end

  def test_total_active_contributors
    WebMock.disable_net_connect!
    stub_github(
      'https://api.github.com/repos/foo/foo',
      body: {
        name: 'foo',
        full_name: 'foo/foo',
        private: false,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-23 07:23:36 UTC'),
        pushed_at: Time.parse('2024-09-23 20:22:51 UTC'),
        size: 19_366,
        stargazers_count: 1,
        forks: 1,
        default_branch: 'master'
      }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/git/trees/master?recursive=true',
      body: { sha: 'abc012345f', tree: [], truncated: false }
    )
    stub_github(
      'https://api.github.com/repos/foo/foo/contributors?per_page=100',
      body: []
    )
    stub_github(
      'https://api.github.com/search/commits?per_page=100&q=repo:foo/foo%20author-date:%3E2024-08-30',
      body: {
        total_count: 7,
        incomplete_results: false,
        items: [
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor@gmail.com', date: Time.parse('2024-09-15 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor@gmail.com', date: Time.parse('2024-09-15 12:23:25 UTC') },
              message: 'Some text',
              tree: { sha: '6e04579960bf67610d' },
              comment_count: 0
            },
            author: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            committer: { login: 'yegor256', id: 526_301, type: 'User', site_admin: false },
            parents: [{ sha: '60cff20bdb66' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor2@gmail.com', date: Time.parse('2024-09-14 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor2@gmail.com', date: Time.parse('2024-09-14 12:23:25 UTC') },
              message: 'Some text 2',
              tree: { sha: 'defa18e4e2250987' },
              comment_count: 0
            },
            author: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false },
            committer: { login: 'yegor257', id: 526_302, type: 'User', site_admin: false },
            parents: [{ sha: 'a04c15bb34fddbba' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor3@gmail.com', date: Time.parse('2024-09-13 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor3@gmail.com', date: Time.parse('2024-09-13 12:23:25 UTC') },
              message: 'Some text 3',
              tree: { sha: 'bb7277441139739b902a' },
              comment_count: 0
            },
            author: { login: 'yegor258', id: 526_303, type: 'User', site_admin: false },
            committer: { login: 'yegor258', id: 526_303, type: 'User', site_admin: false },
            parents: [{ sha: '18db84d469bb727' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-12 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-12 12:23:25 UTC') },
              message: 'Some text 4',
              tree: { sha: '139739b902abb7277441' },
              comment_count: 0
            },
            author: { login: 'yegor259', id: 526_304, type: 'User', site_admin: false },
            committer: { login: 'yegor259', id: 526_304, type: 'User', site_admin: false },
            parents: [{ sha: '469bb72718db84d' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-11 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-11 12:23:25 UTC') },
              message: 'Some text 5',
              tree: { sha: '739b902abb7277441139' },
              comment_count: 0
            },
            author: { login: 'yegor259', id: 526_304, type: 'User', site_admin: false },
            committer: { login: 'yegor259', id: 526_304, type: 'User', site_admin: false },
            parents: [{ sha: 'bb72718db84d469' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-10 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor4@gmail.com', date: Time.parse('2024-09-10 12:23:25 UTC') },
              message: 'Some text 6',
              tree: { sha: '02abb7277441139739b9' },
              comment_count: 0
            },
            committer: { login: 'yegor259', id: 526_304, type: 'User', site_admin: false },
            parents: [{ sha: '718db84d469bb72' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          },
          {
            commit: {
              author: { name: 'Yegor', email: 'yegor5@gmail.com', date: Time.parse('2024-09-09 12:23:25 UTC') },
              committer: { name: 'Yegor', email: 'yegor5@gmail.com', date: Time.parse('2024-09-09 12:23:25 UTC') },
              message: 'Some text 7',
              tree: { sha: '11384739b902abb727744' },
              comment_count: 0
            },
            author: { login: 'yegor260', id: 526_305, type: 'User', site_admin: false },
            committer: { login: 'yegor260', id: 526_305, type: 'User', site_admin: false },
            parents: [{ sha: '69bb72718db8' }],
            repository: {
              id: 799_177_290, name: 'judges-action', full_name: 'zerocracy/judges-action',
              owner: { login: 'zerocracy', id: 24_234_201, type: 'Organization', site_admin: false }
            }
          }
        ]
      }
    )
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      Time.stub(:now, Time.parse('2024-09-29 21:00:00 UTC')) do
        load_it('dimensions-of-terrain', fb)
        f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
        assert_equal(5, f.total_active_contributors)
      end
    end
  end
end
