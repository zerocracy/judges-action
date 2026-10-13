# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntrySignals < Jp::Test
  def test_term_exits_and_cleans_temporary_files
    Dir.mktmpdir do |dir|
      body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
      traps = body[/^declare -a trash=\(\)\n(?:.*\n)*?^trap 'exit 143' TERM\n/]
      refute_nil(traps, 'entry.sh does not define its termination trap')
      temporary = File.join(dir, 'temporary')
      File.write(temporary, 'content')
      script = <<~BASH
        set -e
        #{traps}
        trash+=('#{temporary}')
        echo ready
        sleep 1
        echo continued
      BASH
      Open3.popen3('bash', '-c', script) do |_stdin, stdout, _stderr, process|
        assert_equal('ready', stdout.gets&.chomp)
        Process.kill('TERM', process.pid)
        status = process.value
        output = stdout.read
        assert_equal(143, status.exitstatus)
        refute_includes(output, 'continued')
        refute_path_exists(temporary)
      end
    end
  end
end
