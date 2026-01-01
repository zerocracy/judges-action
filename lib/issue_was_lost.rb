# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/tombstone'
require_relative 'jp'

# The issue was lost.
def Jp.issue_was_lost(where, repository, issue)
  stale = Fbe.fb.query(
    "(and
      (eq where '#{where}')
      (eq repository #{repository})
      (eq issue #{issue})
      (absent stale)
      (absent tombstone))"
  ).each { |f| f.stale = 'issue' }
  return if stale.positive?
  f =
    Fbe.if_absent do |n|
      n.issue = issue
      n.what = 'issue-was-lost'
      n.repository = repository
      n.where = where
    end
  raise "The issue ##{issue} was already lost" unless f
  f.stale = 'issue'
  f.when = Time.now
  Fbe::Tombstone.new.bury!(where, repository, issue)
  $loog.info("The issue #{issue} was marked as lost, #{stale} facts marked as stale")
end
