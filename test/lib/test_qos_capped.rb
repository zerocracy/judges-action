# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require 'minitest/mock'
require_relative '../../lib/qos_search'
require_relative '../test__helper'

class TestQosCapped < Minitest::Test
  def test_says_that_a_full_page_is_a_sample
    log = Loog::Buffer.new
    found = { items: Array.new(100) { |i| { number: i } } }
    assert(Jp.capped?(found, 'repo:foo/foo type:pr', judge: 'quality-of-service', loog: log))
    assert_includes(log.to_s, 'no measurement is reported')
  end

  def test_keeps_quiet_about_a_page_that_is_not_full
    log = Loog::Buffer.new
    found = { items: Array.new(3) { |i| { number: i } } }
    refute(Jp.capped?(found, 'repo:foo/foo type:pr', judge: 'quality-of-service', loog: log))
    assert_empty(log.to_s)
  end

  def test_reports_no_lifetime_when_a_search_answers_a_full_page
    assert_empty(lifetimes(100), 'a full page was reported as the lifetimes of the whole window')
  end

  def test_reports_the_lifetimes_when_the_page_is_not_full
    assert_equal(%w[some_issue_lifetime some_pull_lifetime], lifetimes(3).keys)
  end

  private

  def lifetimes(size)
    $judge = 'quality-of-service'
    $loog = Loog::NULL
    load(File.join(__dir__, '../../judges/quality-of-service/some_issue_lifetime.rb'))
    octo = Object.new
    octo.define_singleton_method(:off_quota?) { |**| false }
    items = Array.new(size) { |i| { number: i, created_at: Time.at(0), closed_at: Time.at(60) } }
    fact = Struct.new(:since, :when).new(Time.parse('2024-08-02T21:00:00Z'), Time.parse('2024-08-09T21:00:00Z'))
    Fbe.stub(:octo, octo) do
      Fbe.stub(:unmask_repos, proc { |&b| b.call('foo/foo') }) do
        Jp.stub(:qosearch, { items: }) { some_issue_lifetime(fact) }
      end
    end
  end
end
