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
        Jp.recovered('foo/foo', 42, ended, branch: 'master', judge: 'quality-of-service', loog: Loog::NULL)
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
        Jp.recovered('foo/foo', 42, Time.now, branch: 'master', judge: 'quality-of-service', loog: Loog::NULL)
      end
    assert_nil(found)
  end

  def test_looks_for_success_on_the_branch_that_broke
    asked = []
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    octo.define_singleton_method(:with_disable_auto_paginate) { |&b| b.call(self) }
    octo.define_singleton_method(:workflow_runs) do |_repo, _workflow, **opts|
      asked << opts[:branch]
      { workflow_runs: [] }
    end
    Fbe.stub(:octo, octo) do
      Jp.recovered('foo/foo', 42, Time.now, branch: 'фича-ä', judge: 'quality-of-service', loog: Loog::NULL)
    end
    assert_equal(['фича-ä'], asked, 'the later success is looked for on another branch than the one that broke')
  end
end
