# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/delete_one'
require 'fbe/fb'
require 'fbe/octo'
require 'fbe/overwrite'

Fbe.consider("(and (eq stale 'who') (eq where 'github') (unique who))") do |f|
  json =
    begin
      Fbe.octo.user(f.who)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The user ##{f.who} is still stale: #{e.message}")
      next
    end
  $loog.info("The user ##{f.who} is not stale, it is @#{json[:login]}")
  Fbe.fb.query("(and (eq stale 'who') (eq who #{f.who}))").each do |f1|
    Fbe.delete_one(f1, 'stale', 'who')
  end
end

Fbe.octo.print_trace!
