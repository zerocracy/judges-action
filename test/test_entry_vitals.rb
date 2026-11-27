# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'test__helper'

class TestEntryVitals < Jp::Test
  def test_points_to_the_root_of_a_user_site
    seed = Random.new_seed
    name = "job#{Random.new(seed).rand(1..99_999)}"
    assert_equal(
      "https://yegor256.github.io/#{name}-vitals.html",
      vitals('yegor256/yegor256.github.io', 'yegor256', name),
      "the vitals URL of a user site is not at its root, seed #{seed}"
    )
  end

  def test_points_to_the_root_of_a_user_site_named_in_another_case
    seed = Random.new_seed
    name = "job#{Random.new(seed).rand(1..99_999)}"
    assert_equal(
      "https://Zerocracy.github.io/#{name}-vitals.html",
      vitals('Zerocracy/zerocracy.GitHub.io', 'Zerocracy', name),
      "the vitals URL of a user site in another case is not at its root, seed #{seed}"
    )
  end

  def test_points_to_the_folder_of_a_project_site
    seed = Random.new_seed
    name = "job#{Random.new(seed).rand(1..99_999)}"
    assert_equal(
      "https://foo.github.io/foo.github.io-pages/#{name}-vitals.html",
      vitals('foo/foo.github.io-pages', 'foo', name),
      "the vitals URL of a project site is not in its folder, seed #{seed}"
    )
  end

  private

  def vitals(repo, owner, name)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^GITHUB_REPO_NAME=.*\n(?:.*\n)*?(?=\ndeclare -a options=\(\)\n)/]
    refute_nil(block, 'No vitals URL block found in entry.sh')
    out, err, status = Open3.capture3(
      { 'GITHUB_REPOSITORY' => repo, 'GITHUB_REPOSITORY_OWNER' => owner, 'name' => name },
      'bash', '-c', "set -e -o pipefail\n#{block}\nprintf '%s' \"${VITALS_URL}\""
    )
    assert_equal(0, status.exitstatus, err)
    out
  end
end
