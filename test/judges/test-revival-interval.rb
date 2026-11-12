# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../../lib/today'
require_relative '../test__helper'

class TestRevivalInterval < Jp::Test
  using SmartFactbase

  [
    { judge: 'revive-user', property: :who, checked: :user_revival_checked, endpoint: 'user' },
    {
      judge: 'revive-repository', property: :repository,
      checked: :repository_revival_checked, endpoint: 'repositories'
    }
  ].each do |kind|
    define_method("test_#{kind[:judge]}_checks_a_missing_entity_once_within_five_days") do
      fb = seed(kind)
      3.times { |day| run_at(kind, fb, day) }
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77", times: 1)
    end
    define_method("test_#{kind[:judge]}_retries_at_the_five_day_boundary") do
      fb = seed(kind)
      run_at(kind, fb, 0)
      run_at(kind, fb, 5)
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77", times: 2)
    end
    define_method("test_#{kind[:judge]}_finds_recent_checks_on_other_facts") do
      fb = seed(kind)
      fb.pick(_id: 2).public_send("#{kind[:checked]}=", Time.utc(2026, 1, 1))
      run_at(kind, fb, 0)
      assert_not_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77")
    end
    define_method("test_#{kind[:judge]}_ignores_checks_from_other_sources") do
      fb = seed(kind)
      fb.with(_id: 3, **{ kind[:property] => 77, kind[:checked] => Time.utc(2026, 1, 1) }, where: 'gitlab')
      run_at(kind, fb, 0)
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77", times: 1)
    end
    define_method("test_#{kind[:judge]}_keeps_distinct_entity_schedules") do
      fb = seed(kind)
      run_at(kind, fb, 0)
      fb.with(_id: 3, **{ kind[:property] => 78 }, where: 'github', stale: kind[:property].to_s)
      stub_github("https://api.github.com/#{kind[:endpoint]}/78", status: 404, body: { message: 'Not Found' })
      run_at(kind, fb, 1)
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/78", times: 1)
    end
    define_method("test_#{kind[:judge]}_retries_forbidden_access_on_the_next_cycle") do
      fb = seed(kind)
      stub_github("https://api.github.com/#{kind[:endpoint]}/77", status: 403, body: { message: 'Forbidden' })
      2.times { run_at(kind, fb, 0) }
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77", times: 2)
    end
    define_method("test_#{kind[:judge]}_revives_every_fact_when_access_returns") do
      assert_empty(recovered(kind).picks(stale: kind[:property].to_s))
    end
    define_method("test_#{kind[:judge]}_clears_the_failed_check_after_recovery") do
      assert_empty(recovered(kind).query("(exists #{kind[:checked]})").each.to_a)
    end
    define_method("test_#{kind[:judge]}_preserves_other_stale_reasons") do
      fb = seed(kind)
      fb.pick(_id: 1).stale = 'branch'
      recovered(kind, fb:)
      assert_equal(['branch'], fb.pick(_id: 1)['stale'])
    end
    define_method("test_#{kind[:judge]}_checks_a_new_disappearance_immediately") do
      fb = recovered(kind)
      fb.pick(_id: 1).stale = kind[:property].to_s
      stub_github("https://api.github.com/#{kind[:endpoint]}/77", status: 404, body: { message: 'Not Found' })
      run_at(kind, fb, 5)
      assert_requested(:get, "https://api.github.com/#{kind[:endpoint]}/77", times: 3)
    end
    define_method("test_#{kind[:judge]}_replaces_the_previous_check_timestamp") do
      fb = seed(kind)
      run_at(kind, fb, 0)
      run_at(kind, fb, 5)
      assert_equal([Time.utc(2026, 1, 6)], fb.pick(_id: 1)[kind[:checked].to_s])
    end
  end

  private

  def seed(kind)
    WebMock.disable_net_connect!
    rate_limit_up
    stub_github("https://api.github.com/#{kind[:endpoint]}/77", status: 404, body: { message: 'Not Found' })
    fb = Factbase.new
    2.times do |index|
      fb.with(_id: index + 1, **{ kind[:property] => 77 }, where: 'github', stale: kind[:property].to_s)
    end
    fb
  end

  def run_at(kind, fb, day)
    Jp.stub(:today, Time.utc(2026, 1, 1) + (day * 86_400)) { load_it(kind[:judge], fb) }
  end

  def recovered(kind, fb: seed(kind))
    run_at(kind, fb, 0)
    stub_github(
      "https://api.github.com/#{kind[:endpoint]}/77",
      body: { id: 77, login: 'alice', full_name: 'foo/foo' }
    )
    run_at(kind, fb, 5)
    fb
  end
end
