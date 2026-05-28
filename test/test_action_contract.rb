# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require_relative 'test__helper'

class TestActionContract < Jp::Test
  def test_cycles_default_is_consistent
    root = File.expand_path('..', __dir__)
    meta = YAML.safe_load_file(File.join(root, 'action.yml'))
    cycles = meta.fetch('inputs').fetch('cycles')
    refute(cycles.fetch('required'))
    assert_equal(2, cycles.fetch('default'))
    assert_includes(File.read(File.join(root, 'entry.sh')), "cycles=2\n")
    assert_includes(
      File.read(File.join(root, 'README.md')),
      '`cycles` (optional) is a number of update cycles to run, defaulting to `2`'
    )
  end
end
