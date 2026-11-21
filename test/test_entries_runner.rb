# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class TestEntriesRunner < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def test_runs_entry_in_a_quoted_checkout_path
    Dir.mktmpdir('entries-runner') do |tmp|
      checkout = File.join(tmp, 'checkout" name')
      copy_runner(checkout)
      marker = File.join(checkout, 'marker')
      write_entry(checkout, "printf 'ran' > \"$1/marker\"\n")
      output, status = run_entries(checkout)
      assert_predicate(status, :success?, output)
      assert(File.file?(marker), "The entry did not run in #{checkout}:\n#{output}")
      write_entry(checkout, "printf 'ran' > \"$1/marker\"\nexit 3\n")
      output, status = run_entries(checkout)
      refute_predicate(status, :success?, "The entry exit status 3 was lost:\n#{output}")
    end
  end

  private

  def copy_runner(checkout)
    FileUtils.mkdir_p(File.join(checkout, 'makes'))
    FileUtils.cp(File.join(ROOT, 'makes', 'entries.sh'), File.join(checkout, 'makes', 'entries.sh'))
    bin = File.join(checkout, 'bin')
    FileUtils.mkdir_p(bin)
    File.write(
      File.join(bin, 'parallel'),
      <<~SH
        #!/usr/bin/env bash
        set -e
        while read -r name; do
            run_test "${name}"
        done
      SH
    )
    File.chmod(0o755, File.join(bin, 'parallel'))
  end

  def write_entry(checkout, body)
    entries = File.join(checkout, 'entries')
    FileUtils.mkdir_p(entries)
    script = File.join(entries, 'check.sh')
    File.write(script, "#!/usr/bin/env bash\nset -e -o pipefail\n#{body}")
    File.chmod(0o755, script)
  end

  def run_entries(checkout)
    Open3.capture2e(
      { 'PATH' => "#{File.join(checkout, 'bin')}:#{ENV.fetch('PATH')}" },
      'bash', 'makes/entries.sh',
      chdir: checkout
    )
  end
end
