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

  def test_up_creates_pull_request_with_pat
    steps = YAML.load_file(File.expand_path('../.github/workflows/up.yml', __dir__))['jobs']['up']['steps']
    step = steps.find { |s| s['uses'].to_s.start_with?('peter-evans/create-pull-request') }
    refute_nil(step, 'up.yml has no create-pull-request step')
    assert_equal('${{ secrets.PAT }}', step.dig('with', 'token'), 'version PR must use the PAT so CI starts')
  end

  def test_every_pull_request_step_uses_the_pat
    steps =
      Dir[File.expand_path('../.github/workflows/*.yml', __dir__)].flat_map do |file|
        YAML.load_file(file).fetch('jobs', {}).flat_map do |_name, job|
          Array(job['steps']).filter_map do |s|
            [File.basename(file), s] if s['uses'].to_s.start_with?('peter-evans/create-pull-request')
          end
        end
      end
    refute_empty(steps, 'no workflow creates a pull request')
    steps.each do |file, step|
      assert_equal(
        '${{ secrets.PAT }}', step.dig('with', 'token'),
        "#{file} must create its pull request with the PAT, otherwise no checks start"
      )
    end
  end

  def test_up_pull_request_targets_master_on_version_branch
    steps = YAML.load_file(File.expand_path('../.github/workflows/up.yml', __dir__))['jobs']['up']['steps']
    step = steps.find { |s| s['uses'].to_s.start_with?('peter-evans/create-pull-request') }
    assert_equal('version-up', step.dig('with', 'branch'), 'the version PR must use the version-up branch')
    assert_equal('master', step.dig('with', 'base'), 'the version PR must target master')
    assert(step.dig('with', 'delete-branch'), 'the version-up branch must be deleted after merge')
  end

  def test_up_checks_out_without_persisting_the_default_token
    steps = YAML.load_file(File.expand_path('../.github/workflows/up.yml', __dir__))['jobs']['up']['steps']
    step = steps.find { |s| s['uses'].to_s.start_with?('actions/checkout') }
    refute_nil(step, 'up.yml has no checkout step')
    refute(step.dig('with', 'persist-credentials'), 'the checkout must not persist the default token next to the PAT')
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
