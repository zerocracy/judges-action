# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestMakesEntries < Jp::Test
  def test_runs_an_entry_in_its_target_directory_from_anywhere
    Dir.mktmpdir do |base|
      Dir.mktmpdir do |elsewhere|
        FileUtils.mkdir_p(File.join(base, 'entries'))
        FileUtils.mkdir_p(File.join(base, 'target/entries-logs'))
        probe = File.join(base, 'entries/probe.sh')
        File.write(probe, "#!/bin/sh\npwd > \"$1/pwd.txt\"\n")
        FileUtils.chmod(0o755, probe)
        out, status = Open3.capture2e(
          { 'base' => base }, 'bash', '-c', "#{runner}run_test probe.sh", chdir: elsewhere
        )
        assert_predicate(status, :success?, out)
        assert_equal(
          File.realpath(File.join(base, 'target/probe.sh')),
          File.realpath(File.read(File.join(base, 'pwd.txt')).strip),
          'the entry did not run in its own target directory'
        )
      end
    end
  end

  private

  def runner
    body = File.read(File.join(File.expand_path('..', __dir__), 'makes/entries.sh'))
    fn = body[/^run_test\(\) \{\n(?:.*\n)*?^\}\n/]
    refute_nil(fn, 'No run_test function found in makes/entries.sh')
    fn
  end
end
