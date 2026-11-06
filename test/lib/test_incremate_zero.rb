# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'judges/options'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremateZero < Minitest::Test
  def test_does_not_load_a_metric_when_the_limit_is_zero
    previous = [$options, $loog]
    $options = Judges::Options.new
    $loog = Loog::NULL
    Dir.mktmpdir do |dir|
      marker = File.join(dir, 'loaded')
      File.write(File.join(dir, 'some_zero_limit.rb'), <<~RUBY)
        File.write(#{marker.inspect}, 'loaded')
        def some_zero_limit(_fact)
          { some_zero_limit: 42 }
        end
      RUBY
      Fbe.stub(:over?, false) do
        Jp.incremate(Factbase.new.insert, dir, 'some', max_per_fact: 0)
      end
      refute_path_exists(marker)
    end
  ensure
    $options, $loog = previous
  end
end
