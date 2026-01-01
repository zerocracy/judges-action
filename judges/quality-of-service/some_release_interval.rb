# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

# Release intervals:
#
# This function is called from the "quality-of-service.rb".
#
# @param [Factbase::Fact] fact The fact just under processing
# @return [Hash] Map with keys as fact attributes and values as integers
def some_release_interval(fact)
  dates = []
  Fbe.unmask_repos do |repo|
    Fbe.octo.releases(repo).each do |json|
      break if json[:published_at] < fact.since || json[:published_at] > fact.when
      dates << json[:published_at]
    end
  end
  dates.sort!
  diffs = (1..(dates.size - 1)).map { |i| dates[i] - dates[i - 1] }
  {
    some_release_interval: diffs
  }
end
