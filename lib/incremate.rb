# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/overwrite'
require 'tago'
require 'time'
require_relative 'jp'

# Incrementally accumulates data into a fact by executing Ruby scripts.
#
# This method finds and executes Ruby scripts in a specified directory that match
# a given prefix pattern. Each script is expected to define a method with the same
# name as the script file (minus the .rb extension) that returns a Hash of data
# to be added to the fact. Scripts are executed in random order to avoid bias.
#
# The method will stop processing scripts if:
# - The GitHub API quota is exhausted
# - The timeout period is exceeded
# - All matching scripts have been processed
#
# @example
#   # Given scripts like total_commits.rb, total_issues.rb in /path/to/scripts/
#   Jp.incremate(fact, '/path/to/scripts', 'total', timeout: 60)
#
# @param [Factbase::Fact] fact The fact object to accumulate data into. May already
#   contain some data. Properties from scripts will be added or overwritten.
# @param [String] dir The directory path where Ruby scripts are located
# @param [String] prefix The filename prefix to match scripts (e.g., "total" matches
#   "total_*.rb" files)
# @param [Integer] timeout Maximum execution time in seconds (default: 30). Processing
#   stops when this limit is exceeded
# @param [Boolean] avoid_duplicate When true, skip adding properties that already
#   exist in the fact (default: false)
# @return [nil] This method modifies the fact in-place and returns nil
def Jp.incremate(fact, dir, prefix, timeout: 30, avoid_duplicate: false)
  start = Time.now
  Dir[File.join(dir, "#{prefix}_*.rb")].shuffle.each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    unless fact[n].nil?
      $loog.debug("#{n} is here: #{fact[n].first}")
      next
    end
    if Fbe.octo.off_quota?
      $loog.info('No GitHub quota left, it is time to stop')
      break
    end
    if Time.now - start > timeout
      $loog.info("We are doing this for too long (#{start.ago} > #{timeout}s), time to stop")
      break
    end
    require_relative rb
    before = Time.now
    h = send(n, fact)
    h.each do |k, v|
      next if avoid_duplicate && fact.all_properties.include?(k.to_s)
      fact = Fbe.overwrite(fact, k.to_s, v)
    end
    $loog.info("Collected #{n} in #{before.ago} (#{start.ago} total): [#{h.map { |k, v| "#{k}: #{v}" }.join(', ')}]")
  end
end
