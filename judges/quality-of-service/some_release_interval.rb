# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_interval(fact)
  intervals = []
  Fbe.unmask_repos do |repo|
    releases =
      begin
        Fbe.octo.releases(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Releases not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to releases for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    dates = []
    releases.each do |json|
      next if json[:published_at].nil?
      next if json[:published_at] > fact.when
      break if json[:published_at] < fact.since
      dates << json[:published_at]
    end
    dates.sort!
    intervals.concat(dates.each_cons(2).map { |pair| pair.last - pair.first })
  end
  {
    some_release_interval: intervals
  }
end
