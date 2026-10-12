# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'

class TestQuantityRequiresPatch < Minitest::Test
  def test_every_metric_requires_the_patch
    Dir[File.join(__dir__, '../../judges/quantity-of-deliverables/total_*.rb')].each do |rb|
      body = File.read(rb)
      next unless body.include?('Fbe.unmask_repos')
      assert_includes(body, "require_relative '../../lib/patches/unmask_repos'", File.basename(rb))
    end
  end
end
