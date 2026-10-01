# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require_relative 'test__helper'

class TestWorkflowConfig < Jp::Test
  def test_valid_yaml
    YAML.load_file(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
  end

  def test_no_stale_baza
    text = File.read(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
    repos = text[/repositories: (\S+)/, 1]
    refute_nil(repos)
    refute_includes(repos.split(','), 'zerocracy/baza')
  end

  def test_dont_cancel_running_cycle
    refute(
      YAML.load_file(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
        .dig('concurrency', 'cancel-in-progress'),
      'a new scheduled tick is allowed to cancel the cycle that is still running between update and push'
    )
  end

  def test_keeps_cycles_in_one_concurrency_group
    refute_nil(
      YAML.load_file(File.expand_path('../.github/workflows/zerocracy.yml', __dir__))
        .dig('concurrency', 'group'),
      'the cycles have no concurrency group, so two of them may update and push the same factbase at once'
    )
  end
end
