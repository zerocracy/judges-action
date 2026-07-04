# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_interval(fact)
  dates = []
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
      dates << json[:published_at]
    end
  end
  dates.sort!
  {
    some_release_interval: (1..(dates.size - 1)).map { |i| dates[i] - dates[i - 1] }
  }
end
