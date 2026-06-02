# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def some_release_interval(fact)
  dates = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.releases(repo).each do |json|
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
