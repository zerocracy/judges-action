# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryProjectName < Jp::Test
  def test_derives_the_project_name_from_a_relative_factbase_path
    assert_includes(update_arguments('data/example-project.fb'), '--option=job_name=example-project')
  end

  def test_derives_the_project_name_from_an_absolute_path_with_spaces
    Dir.mktmpdir do |dir|
      args = update_arguments(File.join(dir, 'my projects', 'example-project.fb'))
      assert_includes(args, '--option=job_name=example-project')
    end
  end

  def test_preserves_an_explicit_project_name
    args = update_arguments('example-project.fb', 'job_name=shared-project')
    assert_equal(['--option=job_name=shared-project'], args.grep(/^--option=job_name=/))
  end

  private

  def update_arguments(factbase, options = '')
    Dir.mktmpdir do |dir|
      output = File.join(dir, 'arguments.json')
      command = File.join(dir, 'judges')
      File.write(command, <<~RUBY)
        #!/usr/bin/env ruby
        require 'json'
        File.write(ENV.fetch('CAPTURE_ARGUMENTS'), JSON.generate(ARGV)) if ARGV.include?('update')
      RUBY
      File.chmod(0o700, command)
      stdout, stderr, status = Open3.capture3(
        {
          'CAPTURE_ARGUMENTS' => output, 'JUDGES' => command, 'SKIP_VERSION_CHECKING' => 'true',
          'GITHUB_WORKSPACE' => dir, 'GITHUB_REPOSITORY' => 'example/project',
          'GITHUB_REPOSITORY_OWNER' => 'example', 'GITHUB_RUN_ID' => nil, 'GITHUB_STEP_SUMMARY' => nil,
          'INPUT_DRY-RUN' => 'true', 'INPUT_GITHUB-TOKEN' => 'test-only-token', 'INPUT_TOKEN' => '',
          'INPUT_FACTBASE' => factbase, 'INPUT_OPTIONS' => options, 'INPUT_VERBOSE' => 'false',
          'INPUT_SQLITE-CACHE' => nil, 'INPUT_REPOSITORIES' => 'example/project'
        },
        'bash', File.join(File.expand_path('..', __dir__), 'entry.sh'), dir
      )
      assert_predicate(status, :success?, "#{stdout}\n#{stderr}")
      JSON.parse(File.read(output))
    end
  end
end
