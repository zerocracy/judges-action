# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryDuplicateOptions < Jp::Test
  def test_passes_job_id_and_action_version_only_once
    Dir.mktmpdir do |dir|
      argv = launch(
        dir,
        'INPUT_OPTIONS' => "job_id=manual\naction_version=9.9.9\nfoo=bar",
        'GITHUB_RUN_ID' => '424242'
      )
      assert_equal(1, argv.grep(/--option=job_id=/).size, argv.grep(/job_id/).inspect)
      assert_equal(1, argv.grep(/--option=action_version=/).size, argv.grep(/action_version/).inspect)
      assert_includes(argv, '--option=job_id=424242')
      assert_includes(argv, "--option=action_version=#{entry_version}")
    end
  end

  def test_uses_the_sqlite_cache_input_instead_of_the_options_pair
    Dir.mktmpdir do |dir|
      cache = File.join(dir, 'from-input.sqlite')
      File.write(cache, '')
      argv = launch(
        dir,
        'INPUT_OPTIONS' => "sqlite_cache=#{File.join(dir, 'from-options.sqlite')}",
        'INPUT_SQLITE-CACHE' => cache
      )
      assert_equal(1, argv.grep(/--option=sqlite_cache=/).size, argv.grep(/sqlite_cache/).inspect)
      assert(argv.any? { |a| a.start_with?('--option=sqlite_cache=') && a.end_with?(cache) })
    end
  end

  private

  def entry_version
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    body[/^VERSION=(.+)$/, 1]
  end

  def launch(dir, extra)
    fake = File.join(dir, 'judges.sh')
    File.write(fake, <<~BASH)
      #!/usr/bin/env bash
      printf '%s\\n' "$@" >> '#{dir}/argv.txt'
    BASH
    File.chmod(0o700, fake)
    env = {
      'JUDGES' => fake, 'SKIP_VERSION_CHECKING' => 'true', 'GITHUB_WORKSPACE' => dir,
      'GITHUB_RUN_ID' => '1', 'GITHUB_REPOSITORY' => 'foo/bar', 'GITHUB_REPOSITORY_OWNER' => 'foo',
      'GITHUB_SERVER_URL' => 'https://github.com', 'INPUT_DRY-RUN' => 'true',
      'INPUT_FACTBASE' => File.join(dir, 'base.fb'), 'INPUT_TOKEN' => 'ZRCY-00000000',
      'INPUT_VERBOSE' => 'false', 'INPUT_GITHUB-TOKEN' => 'ghp_test', 'INPUT_REPOSITORIES' => 'foo/bar',
      'INPUT_OPTIONS' => '', 'INPUT_SQLITE-CACHE' => nil
    }.merge(extra)
    _, err, status = Open3.capture3(
      env,
      'bash', File.join(File.expand_path('..', __dir__), 'entry.sh'), dir
    )
    raise(StandardError, "entry.sh exited with #{status.exitstatus}: #{err}") unless status.success?
    File.read(File.join(dir, 'argv.txt')).lines(chomp: true).grep(/^--option=/)
  end
end
