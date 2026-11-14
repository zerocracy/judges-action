# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryRelativeSelf < Jp::Test
  def test_resolves_explicit_relative_self
    Dir.mktmpdir do |dir|
      src = checkout(dir)
      out, err, status = run_entry(dir, dir, File.join(src, 'entry.sh'), ['src'])
      assert_ran(status, out, err)
      assert_resolved(dir, src)
    end
  end

  def test_resolves_bare_script_name
    Dir.mktmpdir do |dir|
      src = checkout(dir)
      out, err, status = run_entry(dir, src, 'entry.sh', [])
      assert_ran(status, out, err)
      assert_resolved(dir, src)
    end
  end

  def test_keeps_absolute_self
    Dir.mktmpdir do |dir|
      src = checkout(dir)
      out, err, status = run_entry(dir, dir, File.join(src, 'entry.sh'), [src])
      assert_ran(status, out, err)
      assert_resolved(dir, src)
    end
  end

  private

  def checkout(dir)
    src = File.join(dir, 'src')
    Dir.mkdir(src)
    File.write(File.join(src, 'entry.sh'), File.read(File.join(File.expand_path('..', __dir__), 'entry.sh')))
    File.write(File.join(dir, 'argv.txt'), '')
    bin = File.join(dir, 'bin')
    Dir.mkdir(bin)
    File.write(File.join(bin, 'bundle'), <<~BASH)
      #!/usr/bin/env bash
      printf '%s\\n' "$PWD" > '#{dir}/cwd.txt'
      printf '%s\\n' "${BUNDLE_GEMFILE}" > '#{dir}/gemfile.txt'
      printf '%s\\n' "$@" >> '#{dir}/argv.txt'
      printf '0i/0d/0a\\n' > churn.txt
    BASH
    File.chmod(0o700, File.join(bin, 'bundle'))
    src
  end

  def run_entry(dir, cwd, script, args)
    Open3.capture3(
      {
        'PATH' => "#{File.join(dir, 'bin')}:#{ENV.fetch('PATH')}",
        'JUDGES' => nil, 'BUNDLE_GEMFILE' => nil, 'SKIP_VERSION_CHECKING' => 'true',
        'GITHUB_WORKSPACE' => dir, 'GITHUB_RUN_ID' => nil,
        'GITHUB_REPOSITORY' => 'foo/bar', 'GITHUB_REPOSITORY_OWNER' => 'foo',
        'INPUT_DRY-RUN' => 'false', 'INPUT_FACTBASE' => File.join(dir, 'base.fb'),
        'INPUT_TOKEN' => 'ZRCY-00000000', 'INPUT_GITHUB-TOKEN' => 'ghp_fake',
        'INPUT_VERBOSE' => 'false', 'INPUT_REPOSITORIES' => 'foo/bar', 'INPUT_SQLITE-CACHE' => nil
      },
      'bash', script, *args, chdir: cwd
    )
  end

  def assert_ran(status, out, err)
    assert_predicate(
      status, :success?,
      "entry.sh failed with #{status.exitstatus}\nSTDOUT:\n#{out}\nSTDERR:\n#{err}"
    )
  end

  def assert_resolved(dir, src)
    real = File.realpath(src)
    argv = File.readlines(File.join(dir, 'argv.txt'), chomp: true)
    assert_includes(argv, "#{real}/lib", "relative --lib is passed to judges: #{argv.inspect}")
    assert_includes(argv, "#{real}/judges", "relative judges directory is passed to judges: #{argv.inspect}")
    gemfile = File.read(File.join(dir, 'gemfile.txt')).chomp
    assert_equal("#{real}/Gemfile", gemfile, 'BUNDLE_GEMFILE is not absolute')
    cwd = File.read(File.join(dir, 'cwd.txt')).chomp
    assert_equal(real, cwd, 'judges does not run inside the checkout')
  end
end
