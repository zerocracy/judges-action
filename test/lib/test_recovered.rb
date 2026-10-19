# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative '../../lib/recovered'
require_relative '../test__helper'

class TestRecovered < Minitest::Test
  def test_finds_the_success_that_came_after_the_window
    ended = Time.parse('2025-01-10 00:00:00 UTC')
    recovery = Time.parse('2025-01-12 00:00:00 UTC')
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(self) }
    octo.define_singleton_method(:workflow_runs) do |_repo, _workflow, **|
      { workflow_runs: [{ id: 7, updated_at: recovery }] }
    end
    found =
      Fbe.stub(:octo, octo) do
        Jp.recovered('foo/foo', 42, ended, judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_equal(recovery, found)
  end

  def test_answers_nothing_when_nothing_came_after
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(self) }
    octo.define_singleton_method(:workflow_runs) { |_repo, _workflow, **| { workflow_runs: [] } }
    found =
      Fbe.stub(:octo, octo) do
        Jp.recovered('foo/foo', 42, Time.now, judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_nil(found)
  end
end
