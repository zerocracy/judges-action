# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_contributors(_fact)
  contributors = Set.new
  Fbe.unmask_repos do |repo|
    json =
      begin
        Fbe.octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    next if json[:size].nil? || json[:size].zero?
    list =
      begin
        Fbe.octo.contributors(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Contributors not found for #{repo}: #{e.message}")
        next
      rescue Octokit::Forbidden => e
        $loog.warn(
          "[#{$judge}] Access forbidden to contributors for #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    next unless list.is_a?(Array)
    list.each do |contributor|
      contributors << contributor[:id]
    end
  end
  { total_contributors: contributors.count }
end
