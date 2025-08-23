# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/delete_one'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'

stale = Fbe.fb.query("(and (eq stale 'who') (eq where 'github') (unique who))").each.to_a.map(&:who)
stale.each do |who|
  break if Fbe.octo.off_quota?
  begin
    json = Fbe.octo.user(who)
    $loog.info("The user ##{who} is not stale, it is @#{json[:login]}")
    Fbe.fb.query("(and (eq stale 'who') (eq who #{who}))").each do |f|
      Fbe.delete_one(f, 'stale', 'who')
    end
  rescue Octokit::NotFound => e
    $loog.info("The user ##{f.who} is still stale: #{e.message}")
    next
  end
end

Fbe.octo.print_trace!
