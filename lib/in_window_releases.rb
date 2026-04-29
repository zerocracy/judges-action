# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require_relative 'jp'

def Jp.in_window_releases(repo, since, when_)
  Fbe.octo.releases(repo).each do |json|
    next if json[:published_at] > when_
    break if json[:published_at] < since
    yield(json)
  end
end
