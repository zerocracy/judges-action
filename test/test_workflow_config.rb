# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require 'yaml'
require_relative 'test__helper'

class TestWorkflowConfig < Jp::Test
  def test_valid_yaml
    YAML.load_file(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
  end

  def test_no_stale_baza
    text = File.read(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
    repos = text[/repositories: (\S+)/, 1]
    refute_nil(repos)
    refute_includes(repos.split(','), 'zerocracy/baza')
  end

  def test_prints_evaluated_timestamp_in_summary
    steps = YAML.load_file(
      File.expand_path('../.github/workflows/zerocracy.yml', __dir__)
    )['jobs']['zerocracy']['steps']
    script = steps.find { |s| s['name'] == 'Job Summary' }['run'].gsub(/\$\{\{[^}]*\}\}/, 'x')
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'step.md')
      env = { 'GITHUB_STEP_SUMMARY' => file, 'LC_ALL' => 'C' }
      Open3.capture3(env, 'timeout', '10', 'bash', '-c', script, chdir: dir)
      assert_match(
        /^\| Timestamp \| .*\d{2}:\d{2}:\d{2}.* \|$/, File.read(file), 'timestamp row is not the evaluated date'
      )
    end
  end
end
