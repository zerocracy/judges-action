# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require_relative 'test__helper'

class TestEntryCache < Jp::Test
  def test_pushes_factbase_when_cache_upload_fails
    Dir.mktmpdir do |dir|
      assert_includes(commands(dir, 'upload'), 'push', 'the factbase is not pushed after the cache upload failed')
    end
  end

  def test_updates_factbase_when_cache_download_fails
    Dir.mktmpdir do |dir|
      assert_includes(commands(dir, 'download'), 'update', 'the judges do not run after the cache download failed')
    end
  end

  def test_pushes_factbase_before_uploading_cache
    Dir.mktmpdir do |dir|
      list = commands(dir, 'nothing')
      assert_operator(list.index('push'), :<, list.index('upload'), "the cache is uploaded before the push: #{list}")
    end
  end

  private

  def commands(dir, broken)
    log = File.join(dir, 'log.txt')
    stub = File.join(dir, 'judges')
    File.write(
      stub,
      "#!/usr/bin/env bash\nfor a in \"$@\"; do [[ \"$a\" == -* ]] && continue; " \
      "echo \"$a\" >> #{log}; [ \"$a\" == #{broken} ] && exit 1; exit 0; done\n"
    )
    File.chmod(0o755, stub)
    File.write(File.join(dir, 'кэш.sqlite'), '')
    Open3.capture3(
      {
        'JUDGES' => stub, 'GITHUB_WORKSPACE' => dir, 'INPUT_FACTBASE' => 'test.fb',
        'INPUT_TOKEN' => 'ZRCY-00000000', 'INPUT_GITHUB-TOKEN' => 'ghp_0000',
        'INPUT_SQLITE-CACHE' => 'кэш.sqlite',
        'SKIP_VERSION_CHECKING' => 'true', 'GITHUB_RUN_ID' => '', 'INPUT_DRY-RUN' => 'false'
      },
      'bash', File.join(File.expand_path('..', __dir__), 'entry.sh'), File.expand_path('..', __dir__)
    )
    File.readlines(log, chomp: true)
  end
end
