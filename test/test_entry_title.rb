# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryTitle < Jp::Test
  def test_reports_a_title_update_that_github_refused
    out, status = update(22)
    assert_predicate(status, :success?, out)
    assert_includes(out, 'Failed to update workflow run title (non-critical)', out)
  end

  def test_reports_nothing_when_github_took_the_title
    out, status = update(0)
    assert_predicate(status, :success?, out)
    refute_includes(out, 'Failed to update workflow run title', out)
  end

  private

  def update(code)
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    block = body[/^if \[ -n "\$\{GITHUB_RUN_ID\}" \] && .*INPUT_GITHUB-TOKEN.*\n(?:.*\n)*?^fi\n/]
    refute_nil(block, 'No title update block found in entry.sh')
    Dir.mktmpdir do |dir|
      curl = File.join(dir, 'curl')
      File.write(curl, "#!/bin/sh\ncase \" $* \" in *' --fail '*) exit #{code} ;; esac\nexit 0\n")
      FileUtils.chmod(0o755, curl)
      Open3.capture2e(
        {
          'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'GITHUB_RUN_ID' => '1',
          'GITHUB_REPOSITORY' => 'foo/foo', 'INPUT_GITHUB-TOKEN' => 'secret'
        },
        'bash', '-c', "set -e -o pipefail\naction_version=0.0.0\nchurn_val=0\nfb_size=0\n#{block}"
      )
    end
  end
end
