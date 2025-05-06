# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/delete'

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists who))'
  consider do |f|
    Fbe.octo.user(f.who)
  rescue Octokit::NotFound
    $loog.info("GitHub user ##{f.who} is not found")
    Fbe.delete(f, 'who')
  end
end
