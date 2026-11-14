# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'time'

class Fbe::FakeOctokit
  def list_milestones(_repo, _options = {})
    []
  end

  def releases(_repo, _options = {})
    today = ENV.fetch('TODAY', '')
    now = today.empty? ? Time.now : Time.parse(today)
    [60, 120].map { |ago| release('https://github').merge(published_at: now - ago) }
  end
end
