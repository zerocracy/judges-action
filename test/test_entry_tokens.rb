# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryTokens < Jp::Test
  def test_keeps_github_token_out_of_command_line
    seed = Random.new_seed
    token = secret(seed)
    Dir.mktmpdir do |dir|
      launch(dir, 'INPUT_GITHUB-TOKEN' => token, 'INPUT_OPTIONS' => '')
      refute_includes(File.read(File.join(dir, 'argv.txt')), token, "github token is on the command line, seed #{seed}")
    end
  end

  def test_keeps_github_token_from_options_out_of_command_line
    seed = Random.new_seed
    token = secret(seed)
    Dir.mktmpdir do |dir|
      launch(dir, 'INPUT_GITHUB-TOKEN' => '', 'INPUT_OPTIONS' => "max_events=3\ngithub_token=#{token}")
      refute_includes(File.read(File.join(dir, 'argv.txt')), token, "github token is on the command line, seed #{seed}")
    end
  end

  def test_passes_github_token_to_update_through_options_file
    seed = Random.new_seed
    token = secret(seed)
    Dir.mktmpdir do |dir|
      launch(dir, 'INPUT_GITHUB-TOKEN' => token, 'INPUT_OPTIONS' => '')
      assert_includes(
        File.readlines(File.join(dir, 'options.txt'), chomp: true), "github_token=#{token}",
        "github token is not in the options file, seed #{seed}"
      )
    end
  end

  def test_restricts_options_file_to_its_owner
    Dir.mktmpdir do |dir|
      launch(dir, 'INPUT_GITHUB-TOKEN' => secret(Random.new_seed), 'INPUT_OPTIONS' => '')
      assert_equal("600\n", File.read(File.join(dir, 'mode.txt')), 'options file is readable by others')
    end
  end

  private

  def secret(seed)
    rnd = Random.new(seed)
    "ghp_#{Array.new(rnd.rand(8..64)) { [*'a'..'z', *'0'..'9', 'ж', 'ü', '_'].sample(random: rnd) }.join}"
  end

  def launch(dir, env)
    %w[argv.txt options.txt mode.txt].each { |f| File.write(File.join(dir, f), '') }
    fake = File.join(dir, 'judges.sh')
    File.write(fake, <<~BASH)
      #!/usr/bin/env bash
      printf '%s\\n' "$@" >> '#{dir}/argv.txt'
      for a in "$@"; do
        if [[ "${a}" == --options-file=* ]]; then
          cat "${a#--options-file=}" >> '#{dir}/options.txt'
          stat -c %a "${a#--options-file=}" >> '#{dir}/mode.txt'
        fi
      done
    BASH
    File.chmod(0o700, fake)
    _, err, status = Open3.capture3(
      {
        'JUDGES' => fake, 'SKIP_VERSION_CHECKING' => 'true', 'GITHUB_WORKSPACE' => dir, 'GITHUB_RUN_ID' => nil,
        'GITHUB_REPOSITORY' => 'foo/bar', 'GITHUB_REPOSITORY_OWNER' => 'foo', 'INPUT_DRY-RUN' => 'true',
        'INPUT_FACTBASE' => File.join(dir, 'base.fb'), 'INPUT_TOKEN' => 'ZRCY-00000000', 'INPUT_VERBOSE' => 'false',
        'INPUT_REPOSITORIES' => 'foo/bar', 'INPUT_SQLITE-CACHE' => nil
      }.merge(env),
      'bash', File.join(File.expand_path('..', __dir__), 'entry.sh'), dir
    )
    raise(StandardError, "entry.sh exited with #{status.exitstatus} in #{dir}: #{err}") unless status.success?
  end
end
