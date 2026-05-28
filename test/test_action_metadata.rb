# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require_relative 'test__helper'

class TestActionMetadata < Jp::Test
  def test_cycles_default_matches_entrypoint_fallback
    root = File.expand_path('..', __dir__)
    action = YAML.load_file(File.join(root, 'action.yml'))
    cycles = action.fetch('inputs').fetch('cycles')
    refute(cycles.fetch('required'))
    assert_equal(2, cycles.fetch('default'))
    assert_includes(
      File.read(File.join(root, 'entry.sh')),
      "cycles=2\n"
    )
  end
end
