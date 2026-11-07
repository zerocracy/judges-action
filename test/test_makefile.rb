# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestMakefile < Jp::Test
  def test_all_runs_rubocop
    out, status = Open3.capture2e('make', '-n', 'all')
    assert_predicate(status, :success?, out)
    assert_includes(out, 'bundle exec rubocop')
  end

  def test_parallel_build_waits_for_both_consumers
    build(0, 0)
  end

  def test_parallel_build_cleans_after_test_failure
    build(17, 0)
  end

  def test_parallel_build_cleans_after_entry_failure
    build(0, 19)
  end

  private

  def build(tests, entry)
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.expand_path('../Makefile', __dir__), dir)
      %w[target bin makes lib judges].each { |name| FileUtils.mkdir_p(File.join(dir, name)) }
      File.write(File.join(dir, 'target/docker-image.txt'), "test-image\n")
      File.write(File.join(dir, 'image-live'), '')
      %w[test entry].each { |name| File.write(File.join(dir, "target/#{name}.exit"), '99') }
      script(dir, 'bin/bundle', 'exit 0')
      script(dir, 'makes/entries.sh', 'exit 0')
      script(dir, 'bin/docker', <<~BASH)
        case "$1" in
          run)
            sleep 0.2
            test -f image-live || exit 77
            exit #{tests}
            ;;
          rmi) rm image-live ;;
          *) exit 78 ;;
        esac
      BASH
      script(dir, 'test-action.sh', <<~BASH)
        sleep 0.2
        test -f image-live || exit 77
        exit #{entry}
      BASH
      output, status = Open3.capture2e(
        { 'PATH' => "#{dir}/bin:#{ENV.fetch('PATH')}" },
        'make', '-j6', '-o', 'target/docker-image.txt', 'all', chdir: dir
      )
      assert_equal(tests.zero? && entry.zero?, status.success?, output)
      assert_equal(tests.to_s, File.read(File.join(dir, 'target/test.exit')).strip, output)
      assert_equal(entry.to_s, File.read(File.join(dir, 'target/entry.exit')).strip, output)
      refute_path_exists(File.join(dir, 'image-live'), output)
      refute_path_exists(File.join(dir, 'target/docker-image.txt'), output)
    end
  end

  def script(dir, path, body)
    File.write(File.join(dir, path), "#!/usr/bin/env bash\nset -e\n#{body}\n")
    File.chmod(0o700, File.join(dir, path))
  end
end
