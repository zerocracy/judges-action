# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestMakefile < Jp::Test
  def test_all_runs_rubocop
    out, status = Open3.capture2e('make', '-n', 'all')
    assert_predicate(status, :success?, out)
    assert_includes(out, 'bundle exec rubocop')
  end
end
