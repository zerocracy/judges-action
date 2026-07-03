# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/unmask_repos'

module Fbe
  class << self
    def unmask_repos( # rubocop:disable Elegant/GoodMethodName
      options: $options, global: $global, loog: $loog, epoch: $epoch || Time.now, kickoff: $kickoff || Time.now,
      quota_aware: true, lifetime_aware: true, timeout_aware: true
    )
      raise(Fbe::Error, 'Repositories mask is not specified') unless options.repositories
      raise(Fbe::Error, 'Repositories mask is empty') if options.repositories.empty?
      return if block_given? && Fbe.over?(
        global:, options:, loog:, epoch:, kickoff:, quota_aware:, lifetime_aware:, timeout_aware:
      )
      repos = []
      octo = Fbe.octo(loog:, global:, options:)
      masks = (options.repositories || '').split(',')
      masks.reject { |m| m.start_with?('-') }.each do |mask|
        unless mask.include?('*')
          repos << mask
          next
        end
        re = Fbe.mask_to_regex(mask)
        org = mask.split('/')[0]
        list =
          begin
            octo.organization_repositories(org, type: 'all')
          rescue Octokit::NotFound
            octo.repositories(org)
          end
        list.each do |r|
          repos << r[:full_name] if re.match?(r[:full_name])
        end
      end
      masks.select { |m| m.start_with?('-') }.each do |mask|
        re = Fbe.mask_to_regex(mask[1..])
        repos.reject! { |r| re.match?(r) }
      end
      repos.reject! do |repo|
        octo.repository(repo)[:archived]
      rescue Octokit::NotFound, Octokit::Deprecated, Octokit::TooManyRequests => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        false
      rescue Octokit::Forbidden, Octokit::TooManyRequests => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        false
      end
      raise(Fbe::Error, "No repos found matching: #{options.repositories.inspect}") if repos.empty?
      repos.shuffle!
      loog.debug("Scanning #{repos.size} repositories: #{repos.joined}...")
      repos.each do |repo|
        octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated, Octokit::Forbidden # rubocop:disable Lint/SuppressedException
      end
      return repos unless block_given?
      repos.each do |repo|
        break if Fbe.over?(global:, options:, loog:, epoch:, kickoff:, quota_aware:, lifetime_aware:, timeout_aware:)
        yield(repo)
      end
    end
  end
end
