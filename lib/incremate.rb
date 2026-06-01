# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'elapsed'
require 'fbe/octo'
require 'fbe/over'
require 'fbe/overwrite'
require 'tago'
require 'time'
require_relative 'jp'

def Jp.incremate(fact, dir, prefix, avoid_duplicate: false, pause: 0,
                 max_per_fact: nil,
                 epoch: $epoch || Time.now, kickoff: $kickoff || Time.now)
  evaluated = 0
  Dir[File.join(dir, "#{prefix}_*.rb")].shuffle.each do |rb|
    n = File.basename(rb).gsub(/\.rb$/, '')
    if fact[n]
      $loog.debug("#{n} is here: #{fact[n].first}")
      next
    end
    break if Fbe.over?(epoch:, kickoff:)
    if pause.positive? && evaluated.positive?
      $loog.debug("Pausing for #{pause}s before next #{prefix}_* evaluation...")
      sleep(pause)
    end
    $loog.info(
      [
        "Starting to evaluate #{n}",
        (", #{($options.lifetime - Time.now.to_f + Float(epoch)).seconds} of lifetime left" if $options.lifetime),
        (", #{($options.timeout - Time.now.to_f + Float(kickoff)).seconds} of timeout left" if $options.timeout),
        '...'
      ].compact.join
    )
    require_relative(rb)
    elapsed($loog, level: Logger::INFO) do
      h = __send__(n, fact)
      h.each do |k, v|
        next if avoid_duplicate && fact.all_properties.include?(k.to_s)
        Array(v).each { fact.__send__("#{k}=", _1) }
      end
      throw(:"Collected #{n}: [#{h.map { |k, v| "#{k}: #{v}" }.join(', ')}]")
    end
    evaluated += 1
    break if max_per_fact && evaluated >= max_per_fact
  end
end
