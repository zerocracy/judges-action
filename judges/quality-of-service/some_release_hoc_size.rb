# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_hoc_size(fact)
  grouped = {}
  hocs = []
  commits = []
  Fbe.unmask_repos do |repo|
    releases =
      begin
        Fbe.octo.releases(repo)
      rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
        $loog.info("Releases not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to releases for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    releases.each do |json|
      next if json[:published_at].nil?
      next if json[:published_at] > fact.when
      break if json[:published_at] < fact.since
      (grouped[repo] ||= []) << json
    end
  end
  grouped.each do |repo, releases|
    releases.reverse.each_cons(2) do |first, last|
      compare =
        begin
          Fbe.octo.compare(repo, first[:tag_name], last[:tag_name])
        rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
          $loog.info("Compare not found for #{repo}@#{first[:tag_name]}..#{last[:tag_name]}: #{e.message}")
          next
        rescue Octokit::Forbidden => e
          $loog.warn(
            "[#{$judge}] Access forbidden to compare for #{repo} " \
            "(transient, will retry next cycle): #{e.class}: #{e.message}"
          )
          next
        end
      hocs << compare[:files].sum { |file| file[:changes] }
      commits << compare[:total_commits]
    end
  end
  {
    some_release_hoc_size: hocs,
    some_release_commits_size: commits
  }
end
