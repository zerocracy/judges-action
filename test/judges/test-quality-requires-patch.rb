# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'open3'
require_relative '../test__helper'

class TestQualityRequiresPatch < Minitest::Test
  def test_every_metric_loads_the_patch
    root = File.expand_path('../..', __dir__)
    patch = File.join(root, 'lib/patches/unmask_repos.rb')
    lacking =
      Dir[File.join(root, 'judges/quality-of-service/some_*.rb')].reject do |rb|
        out, = Open3.capture3('ruby', '-e', "require #{rb.inspect}; print($LOADED_FEATURES.include?(#{patch.inspect}))")
        out == 'true'
      end
    assert_empty(lacking.map { |rb| File.basename(rb) }, 'quality metrics do not load the unmask_repos patch')
  end
end
