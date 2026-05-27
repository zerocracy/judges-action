# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/unmask_repos'

def total_issues(_fact)
  issues = 0
  pulls = 0
  Fbe.unmask_repos do |repo|
    json =
      begin
        Fbe.github_graph.total_issues_and_pulls(*repo.split('/'))
      rescue StandardError => e
        $loog.warn(
          "[#{$judge}] Can't count issues and pulls in #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        next
      end
    issues += json['issues']
    pulls += json['pulls']
  end
  { total_issues: issues, total_pulls: pulls }
end
