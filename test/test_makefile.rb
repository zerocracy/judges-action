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

  def test_removing_a_judge_source_requires_rebuild
    with_image do |dir|
      FileUtils.rm(File.join(dir, 'judges/foo/foo.rb'))
      assert_equal(1, make_q(dir), 'removed judge source must invalidate the image')
    end
  end

  def test_removing_a_top_level_source_requires_rebuild
    with_image do |dir|
      FileUtils.rm(File.join(dir, 'lib/bar.rb'))
      assert_equal(1, make_q(dir), 'removed top-level source must invalidate the image')
    end
  end

  def test_adding_a_judge_source_requires_rebuild
    with_image do |dir|
      FileUtils.mkdir_p(File.join(dir, 'judges/baz'))
      File.write(File.join(dir, 'judges/baz/baz.rb'), '')
      assert_equal(1, make_q(dir), 'added judge source must invalidate the image')
    end
  end

  def test_modifying_a_judge_source_requires_rebuild
    with_image do |dir|
      FileUtils.touch(File.join(dir, 'judges/foo/foo.rb'))
      assert_equal(1, make_q(dir), 'modified judge source must invalidate the image')
    end
  end

  def test_keeps_a_fresh_image_marker
    with_image do |dir|
      assert_equal(0, make_q(dir), 'fresh image marker must stay up to date')
    end
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

  def with_image
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.join(__dir__, '../Makefile'), dir)
      %w[Dockerfile entry.sh Gemfile Gemfile.lock].each do |file|
        File.write(File.join(dir, file), '')
      end
      FileUtils.mkdir_p([File.join(dir, 'lib'), File.join(dir, 'judges/foo'), File.join(dir, 'target')])
      File.write(File.join(dir, 'lib/bar.rb'), '')
      File.write(File.join(dir, 'judges/foo/foo.rb'), '')
      File.write(File.join(dir, 'target/docker-image.txt'), "sha\n")
      now = Time.now
      %w[lib judges lib/bar.rb judges/foo judges/foo/foo.rb].each do |path|
        File.utime(now - 10, now - 10, File.join(dir, path))
      end
      %w[Makefile Dockerfile entry.sh Gemfile Gemfile.lock].each do |file|
        File.utime(now - 10, now - 10, File.join(dir, file))
      end
      File.utime(now - 5, now - 5, File.join(dir, 'target/docker-image.txt'))
      yield(dir)
    end
  end

  def make_q(dir)
    _, status = Open3.capture2e('make', '-q', 'target/docker-image.txt', chdir: dir)
    status.exitstatus
  end

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
