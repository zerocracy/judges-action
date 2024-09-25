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
    load_it('dimensions-of-terrain', fb, Judges::Options.new({ 'repositories' => 'foo/foo', 'testing' => true }))
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
      'https://api.github.com/repos/foo/foo/releases?per_page=100',
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
    fb = Factbase.new
    Fbe.stub(:github_graph, Fbe::Graph::Fake.new) do
      load_it('dimensions-of-terrain', fb)
      f = fb.query("(eq what 'dimensions-of-terrain')").each.to_a.first
      assert_equal(7, f.total_files)
    end
  end
end
