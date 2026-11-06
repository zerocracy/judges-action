# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntriesRunner < Jp::Test
  def test_runs_nested_script_at_its_own_path
    with_runner do |dir|
      script(dir, 'check.sh', 0, 'root')
      script(dir, 'nested/check.sh', 17, 'nested')
      out, status = run_runner(dir)
      refute_predicate(status, :success?, out)
      log = File.read(File.join(dir, 'executed.log'))
      assert_includes(log, 'root')
      assert_includes(log, 'nested')
      assert_includes(out, '❌ nested/check.sh failed')
      assert_equal(1, out.scan('👍🏻 check.sh passed').size)
      assert_includes(File.read(File.join(dir, 'target/entries-logs/check.sh.txt')), 'root-token')
      assert_includes(File.read(File.join(dir, 'target/entries-logs/nested/check.sh.txt')), 'nested-token')
    end
  end

  def test_reports_nested_non_executable
    with_runner do |dir|
      script(dir, 'check.sh', 0, 'root')
      path = File.join(dir, 'entries/nested/check.sh')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#!/bin/bash\nexit 0\n")
      FileUtils.chmod(0o644, path)
      out, status = run_runner(dir)
      refute_predicate(status, :success?, out)
      assert_includes(out, 'nested/check.sh')
    end
  end

  private

  def with_runner
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'makes'))
      FileUtils.cp(File.expand_path('../makes/entries.sh', __dir__), File.join(dir, 'makes/entries.sh'))
      yield(dir)
    end
  end

  def script(dir, name, code, marker)
    path = File.join(dir, 'entries', name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/bash\necho #{marker}-token\necho #{marker} >> \"$1/executed.log\"\nexit #{code}\n")
    FileUtils.chmod(0o755, path)
  end

  def run_runner(dir)
    Open3.capture2e('bash', 'makes/entries.sh', chdir: dir)
  end
end
