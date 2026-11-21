# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require_relative '../../lib/recovered'
require_relative '../test__helper'

class TestRecovered < Minitest::Test
  def test_finds_the_success_that_came_after_the_window
    ended = Time.parse('2025-01-10 03:00:00 +03:00')
    recovery = Time.parse('2025-01-12 00:00:00 UTC')
    calls = []
    octo = fake_octo([{ id: 7, updated_at: recovery }], calls)
    found =
      Fbe.stub(:octo, octo) do
        Jp.recovered('foo/foo', 42, ended, judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_equal(recovery, found)
    assert_equal([['foo/foo', 42, { status: 'success', created: '>2025-01-10T00:00:00Z', per_page: 1 }]], calls)
  end

  def test_answers_nothing_when_nothing_came_after
    found =
      Fbe.stub(:octo, fake_octo([])) do
        Jp.recovered('foo/foo', 42, Time.now, judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_nil(found)
  end

  private

  def fake_octo(runs, calls = [])
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&block| block.call(self) }
    octo.define_singleton_method(:workflow_runs) do |repo, workflow, **args|
      calls << [repo, workflow, args]
      { workflow_runs: args[:status] == 'success' ? runs : [] }
    end
    octo
  end
end
