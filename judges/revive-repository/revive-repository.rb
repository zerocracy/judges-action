# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/consider'
require 'fbe/delete_one'
require 'fbe/fb'
require 'fbe/octo'
require 'octokit'

Fbe.consider("(and (eq stale 'repository') (eq where 'github') (unique repository))") do |f|
  json =
    begin
      Fbe.octo.repository(f.repository)
    rescue Octokit::NotFound, Octokit::Deprecated => e
      $loog.info("The repository ##{f.repository} is still stale: #{e.message}")
      next
    rescue Octokit::Forbidden => e
      $loog.warn(
        "[#{$judge}] The repository ##{f.repository} is still stale (access forbidden): #{e.class}: #{e.message}"
      )
      next
    end
  $loog.info("The repository ##{f.repository} is not stale, it is #{json[:full_name]}")
  Fbe.fb.query("(and (eq stale 'repository') (eq where 'github') (eq repository #{f.repository}))").each do |f1|
    Fbe.delete_one(f1, 'stale', 'repository')
  end
end

Fbe.octo.print_trace!
