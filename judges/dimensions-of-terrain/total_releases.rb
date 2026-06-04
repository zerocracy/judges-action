# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_releases(_fact)
  total = 0
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
    next unless releases.is_a?(Array)
    releases.each do |_|
      total += 1
    end
  end
  { total_releases: total }
end
