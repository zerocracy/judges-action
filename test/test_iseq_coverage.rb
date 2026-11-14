# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'coverage'
require 'tmpdir'
require_relative 'test__helper'

class TestIseqCoverage < Jp::Test
  def test_repeated_eval_of_one_iseq_keeps_the_first_counters
    skip('coverage is off') unless Coverage.running?
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'judge.rb')
      File.write(
        path,
        "if ENV['COV_ONE']\n  a = 1\nend\nif ENV['COV_TWO']\n  b = 2\nend\n"
      )
      iseq = RubyVM::InstructionSequence.compile_file(path)
      ENV['COV_ONE'] = '1'
      iseq.eval
      ENV.delete('COV_ONE')
      ENV['COV_TWO'] = '1'
      iseq.eval
      lines = Coverage.peek_result.fetch(path)[:lines]
      assert_predicate(lines[1], :positive?, 'the first eval line must survive the second eval')
      assert_predicate(lines[4], :positive?, 'the second eval line must be counted')
    ensure
      ENV.delete('COV_ONE')
      ENV.delete('COV_TWO')
    end
  end
end
