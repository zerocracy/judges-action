# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require_relative '../../lib/today'
require_relative '../test__helper'

class TestToday < Minitest::Test
  def test_returns_now_when_env_var_is_absent
    ENV.delete('TODAY')
    now = Time.now
    Time.stub(:now, now) do
      assert_equal(Integer(now.utc), Integer(Jp.today))
    end
  end

  def test_returns_now_when_env_var_is_empty
    ENV['TODAY'] = ''
    now = Time.now
    Time.stub(:now, now) do
      assert_equal(Integer(now.utc), Integer(Jp.today))
    end
  ensure
    ENV.delete('TODAY')
  end

  def test_parses_env_var_when_present
    ENV['TODAY'] = '2025-03-15T00:00:00Z'
    assert_equal(Integer(Time.parse('2025-03-15T00:00:00Z')), Integer(Jp.today))
  ensure
    ENV.delete('TODAY')
  end
end
