# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/unmask_repos'

def total_builds_ran(fact)
  total =
    Fbe.unmask_repos.sum do |repo|
      Fbe.octo.with_disable_auto_paginate do |octo|
        octo.repository_workflow_runs(repo, created: ">#{fact.since.utc.iso8601[0..9]}", per_page: 1)[:total_count]
      end
    end
  { total_builds_ran: total }
end
