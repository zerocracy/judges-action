# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'fileutils'
require 'judges/options'
require 'tmpdir'
require_relative '../../lib/incremate'
require_relative '../test__helper'

class TestIncremateDirectory < Jp::Test
  def test_finds_a_metric_in_a_directory_with_literal_brackets
    previous = $options
    logger = $loog
    $options = Judges::Options.new({})
    $loog = Loog::NULL
    Dir.mktmpdir do |root|
      directory = File.join(root, 'metrics[2]')
      FileUtils.mkdir(directory)
      File.write(File.join(directory, 'some_bracket.rb'), <<~RUBY)
        def some_bracket(_f)
          { some_bracket: 42 }
        end
      RUBY
      fact = Factbase.new.insert
      Fbe.stub(:over?, false) { Jp.incremate(fact, directory, 'some') }
      assert_equal([42], fact['some_bracket'], 'the metric must be loaded from the specified directory')
    end
  ensure
    $options = previous
    $loog = logger
  end
end
