# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'

class TestDockerfile < Minitest::Test
  def test_installs_locked_bundle
    dockerfile = File.read(File.join(__dir__, '..', 'Dockerfile'))
    refute_match(/\bbundle\s+update\b/, dockerfile)
    refute_match(/\bbundle\s+install\s+--deployment\b/, dockerfile)
    assert_match(/\bbundle\s+config\s+set\s+deployment\s+true\b/, dockerfile)
    assert_match(/\bbundle\s+install\b/, dockerfile)
  end
end
