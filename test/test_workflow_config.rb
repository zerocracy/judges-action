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
end
