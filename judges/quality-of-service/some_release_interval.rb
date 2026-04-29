# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/in_window_releases'

def some_release_interval(fact)
  dates = []
  Fbe.unmask_repos do |repo|
    Jp.in_window_releases(repo, fact.since, fact.when) do |json|
      dates << json[:published_at]
    end
  end
  dates.sort!
  diffs = (1..(dates.size - 1)).map { |i| dates[i] - dates[i - 1] }
  {
    some_release_interval: diffs
  }
end
