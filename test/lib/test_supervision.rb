# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../../lib/supervision'
require_relative '../test__helper'

class TestSupervision < Minitest::Test
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

  def test_supervision_keeps_original_exception_for_non_utf8_messages
    %w[UTF-16LE UTF-32LE].each do |encoding|
      $loog = Loog::Buffer.new
      error = RuntimeError.new('some error'.encode(encoding))
      raised =
        assert_raises(RuntimeError) do
          Jp.supervision({ 'repo' => 'zerocracy/judges-action' }) do
            raise(error)
          end
        end
      assert_same(error, raised)
      $loog.to_s.then do |s|
        assert_match('RuntimeError: some error', s)
        assert_match('"repo": "zerocracy/judges-action"', s)
      end
    end
  end

  def test_supervision_keeps_original_exception_for_inconvertible_message_encoding
    $loog = Loog::Buffer.new
    error = RuntimeError.new((+'some error').force_encoding(Encoding::UTF_7))
    raised =
      assert_raises(RuntimeError) do
        Jp.supervision({ 'repo' => 'zerocracy/judges-action' }) do
          raise(error)
        end
      end
    assert_same(error, raised)
    $loog.to_s.then do |s|
      assert_match('RuntimeError: "', s)
      assert_match('"repo": "zerocracy/judges-action"', s)
    end
  end
end
