# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/fb'
require 'fbe/if_absent'
require 'fbe/tombstone'
require_relative 'jp'

# @todo #2074:30min Bury through the given "fb", once zerocracy/fbe#843 lets Fbe.overwrite run in a txn.
def Jp.issue_was_lost(where, repository, issue, fb: Fbe.fb)
  stale =
    fb.query(
      "(and
      (eq where '#{where}')
      (eq repository #{repository})
      (eq issue #{issue})
      (absent stale)
      (absent tombstone))"
    ).each { |f| f.stale = 'issue' }
  Fbe::Tombstone.new.bury!(where, repository, issue)
  if stale.positive?
    $loog.info("The issue #{issue} was marked as lost, #{stale} facts marked as stale")
    return
  end
  f =
    Fbe.if_absent(fb:) do |n|
      n.where = where
      n.repository = repository
      n.issue = issue
      n.what = 'issue-was-lost'
    end
  if f.nil?
    $loog.warn("The issue ##{issue} was already lost")
    return
  end
  f.stale = 'issue'
  f.when = Time.now
  $loog.info("The issue #{issue} was marked as lost")
end
