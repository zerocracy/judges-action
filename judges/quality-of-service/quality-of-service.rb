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

require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'
require 'fbe/unmask_repos'
require 'fbe/regularly'

start = Time.now
Fbe.regularly('quality', 'qos_interval', 'qos_days') do |f|
  Dir[File.join(__dir__, 'average_*.rb')].each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    next unless f[n].nil?
    if Fbe.octo.off_quota
      $loog.info('No GitHub quota left, it is time to stop')
      break
    end
    if Time.now - start > 5 * 60
      $loog.info('We are doing this for too long, time to stop')
      break
    end
    require_relative rb
    send(n, f).each { |k, v| f = Fbe.overwrite(f, k.to_s, v) }
  end

  # Release hoc and commit size
  repo_releases = {}
  hocs = []
  commits = []
  Fbe.unmask_repos.each do |repo|
    Fbe.octo.releases(repo).each do |json|
      break if json[:published_at] < f.since
      (repo_releases[repo] ||= []) << json
    end
  end
  repo_releases.each do |repo, releases|
    releases.reverse.each_cons(2) do |first, last|
      Fbe.octo.compare(repo, first[:tag_name], last[:tag_name]).then do |json|
        hocs << json[:files].map { |file| file[:changes] }.sum
        commits << json[:total_commits]
      end
    end
  end
  f.average_release_hoc_size = hocs.empty? ? 0 : hocs.sum.to_f / hocs.size
  f.average_release_commits_size = commits.empty? ? 0 : commits.sum.to_f / commits.size

  # Issue and PR lifetimes:
  { issue: 'average_issue_lifetime', pr: 'average_pull_lifetime' }.each do |type, prop|
    ages = []
    Fbe.unmask_repos.each do |repo|
      q = "repo:#{repo} type:#{type} closed:>#{f.since.utc.iso8601[0..9]}"
      ages +=
        Fbe.octo.search_issues(q)[:items].map do |json|
          next if json[:closed_at].nil?
          next if json[:created_at].nil?
          json[:closed_at] - json[:created_at]
        end
    end
    ages.compact!
    f.send("#{prop}=", ages.empty? ? 0 : ages.inject(&:+).to_f / ages.size)
  end
end
