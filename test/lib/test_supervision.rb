# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/supervision'
require_relative '../test__helper'

class TestSupervision < Minitest::Test
  class NoJson
    def to_json(*)
      raise(ArgumentError, 'no JSON here')
    end

    def inspect
      'NO-JSON-INSPECT'
    end
  end

  class NoInspect
    def to_json(*)
      raise(ArgumentError, 'no JSON here')
    end

    def inspect
      raise(RuntimeError, 'no inspect here')
    end
  end

  def test_supervision
    $loog = Loog::Buffer.new
    assert_raises(RuntimeError) do
      Jp.supervision({ 'repo' => 'zerocracy/judges-action', 'issue' => 125 }) do
        raise(RuntimeError, 'some error')
      end
    end
    $loog.to_s.then do |s|
      assert_match('RuntimeError: some error', s)
      assert_match('"repo": "zerocracy/judges-action"', s)
      assert_match('"issue": 125', s)
    end
  end

  def test_logs_serialization_failure_and_keeps_original_error
    loog = Loog::Buffer.new
    assert_raises(RuntimeError) do
      Jp.supervision({ 'bad' => NoJson.new }, loog:) do
        raise(RuntimeError, 'some error')
      end
    end
    assert_match('Failed to serialize context', loog.to_s)
  end

  def test_logs_context_inspect_when_serialization_fails
    loog = Loog::Buffer.new
    assert_raises(RuntimeError) do
      Jp.supervision({ 'bad' => NoJson.new }, loog:) do
        raise(RuntimeError, 'some error')
      end
    end
    assert_match('NO-JSON-INSPECT', loog.to_s)
  end

  def test_keeps_original_error_when_inspect_also_fails
    loog = Loog::Buffer.new
    error =
      assert_raises(RuntimeError) do
        Jp.supervision({ 'bad' => NoInspect.new }, loog:) do
          raise(RuntimeError, 'some error')
        end
      end
    assert_equal('some error', error.message)
  end
end
