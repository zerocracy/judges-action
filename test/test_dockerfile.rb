# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestDockerfile < Jp::Test
  def test_installs_locked_bundle
    dockerfile = File.read(File.join(__dir__, '..', 'Dockerfile'))
    refute_includes(dockerfile, 'bundle update')
    refute_includes(dockerfile, 'bundle install --deployment')
    assert_includes(dockerfile, 'bundle config set frozen true')
    assert_includes(dockerfile, 'bundle install --gemfile=/action/Gemfile')
  end

  def test_makefile_runs_judges_through_bundle
    makefile = File.read(File.join(__dir__, '..', 'Makefile'))
    assert_includes(makefile, 'bundle exec judges test')
  end
end
