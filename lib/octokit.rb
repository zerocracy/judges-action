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

def octokit
  $octokit ||= begin
    o = Octokit::Client.new
    unless $options.github_token.nil?
      token = $options.github_token
      o = Octokit::Client.new(access_token: token)
      $loog.info("Accessing GitHub with a token (#{token.length} chars)")
    end
    o
  end
  if $options.testing.nil?
    Obk.new($octokit, pause: 500)
  else
    FakeOctokit.new
  end
end

def repositories
  $options.github_repositories.split(',').each do |repo|
    $loog.info("Scanning #{repo}...")
    yield repo
  end
end

# Fake GitHub client, for tests.
class FakeOctokit
  def add_comment(repo, issue, text)
    # nothing
  end

  def search_issues(_query)
    { items: [] }
  end

  def repository_events(_repo)
    []
  end
end
