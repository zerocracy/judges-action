# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'octokit'
require_relative 'jp'

def Jp.recovered(repo, workflow, since, judge: $judge, loog: $loog)
  return if Fbe.octo.off_quota?
  runs =
    Fbe.octo.with_disable_auto_paginate do |octo|
      octo.workflow_runs(repo, workflow, status: 'success', created: ">#{since.utc.iso8601}", per_page: 1)
    end[:workflow_runs]
  return if runs.nil? || runs.empty?
  runs.first[:updated_at]
rescue Octokit::NotFound, Octokit::Deprecated => e
  loog.info("No later runs of workflow ##{workflow} in #{repo}: #{e.message}")
  nil
rescue Octokit::Forbidden => e
  loog.warn(
    "[#{judge}] Access forbidden to later runs of workflow ##{workflow} in #{repo} " \
    "(transient, will retry next cycle): #{e.class}: #{e.message}"
  )
  nil
end
