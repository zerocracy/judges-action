# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestDockerfile < Jp::Test
  def test_installs_locked_bundle
    dockerfile = File.read(File.join(__dir__, '..', 'Dockerfile'))
    refute_includes(dockerfile, 'bundle update')
    assert_includes(dockerfile, 'bundle config set frozen true')
    assert_includes(dockerfile, 'bundle install --gemfile=/action/Gemfile')
  end
end
