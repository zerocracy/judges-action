# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require 'loog'
require 'time'
require_relative '../../judges/quality-of-service/some_triage_time'
require_relative '../test__helper'

class TestTriageCutoff < Jp::Test
  def test_excludes_labels_after_the_measurement
    moment = Time.iso8601('2026-10-02T00:00:00.500000000Z')
    scenarios = [[], [moment + 86_400], [moment], [moment - 3600, moment + 86_400], [moment - 0.25], [moment + 0.25]]
    scenarios.each do |labels|
      fb = Factbase.new
      labels.each do |stamp|
        event = fb.insert
        event.what = 'label-was-attached'
        event.repository = 42
        event.issue = 7
        event.where = 'github'
        event.label = 'bug'
        event.when = stamp
      end
      fact = Factbase.new.insert
      fact.since = moment - (30 * 86_400)
      fact.when = moment
      client = Object.new
      client.define_singleton_method(:off_quota?) { false }
      client.define_singleton_method(:repo_id_by_name) { |_repo| 42 }
      pmp = Struct.new(:quality).new(Struct.new(:qos_min_triage_seconds).new(Struct.new(:value).new(60)))
      issue = { number: 7, created_at: moment - 86_400 }
      Fbe.stub(:unmask_repos, ->(&block) { block.call('acme/project') }) do
        Fbe.stub(:octo, client) do
          Fbe.stub(:fb, fb) do
            Fbe.stub(:pmp, pmp) do
              Jp.stub(:qosearch, { items: [issue] }) do
                first = labels.select { |stamp| stamp <= moment }.min
                expected = first ? [first - issue[:created_at]] : []
                assert_equal(expected, some_triage_time(fact)[:some_triage_time])
              end
            end
          end
        end
      end
    end
  end
end
