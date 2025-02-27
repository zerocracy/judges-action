# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'tago'
require 'fbe/octo'
require 'fbe/overwrite'
require_relative 'jp'

# Incrementally accumulates data into a fact, using Ruby scripts
# found in the directory provided, by the prefix.
#
# @param [Factbase::Fact] fact The fact to put data into (some data already there)
# @param [String] dir Where to find Ruby scripts
# @param [String] prefix The prefix to use for scripts (e.g. "total")
# @return nil
def Jp.incremate(fact, dir, prefix)
  start = Time.now
  Dir[File.join(dir, "#{prefix}_*.rb")].shuffle.each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    unless fact[n].nil?
      $loog.info("#{n} is here: #{fact[n].first}")
      next
    end
    if Fbe.octo.off_quota
      $loog.info('No GitHub quota left, it is time to stop')
      break
    end
    if Time.now - start > 5 * 60
      $loog.info("We are doing this for too long (#{start.ago}), time to stop")
      break
    end
    require_relative rb
    before = Time.now
    h = send(n, fact)
    h.each { |k, v| fact = Fbe.overwrite(fact, k.to_s, v) }
    $loog.info("Collected #{n} in #{before.ago} (#{start.ago} total): [#{h.map { |k, v| "#{k}: #{v}" }.join(', ')}]")
  end
end
