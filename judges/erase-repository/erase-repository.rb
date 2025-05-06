# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/conclude'
require 'fbe/delete'

Fbe.conclude do
  quota_aware
  on '(and (eq where "github") (exists repository))'
  consider do |f|
    Fbe.octo.repository(f.repository)
  rescue Octokit::NotFound
    $loog.info("GitHub repository ##{f.repository} is not found")
    Fbe.delete(f, 'repository')
  end
end
