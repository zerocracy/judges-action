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
          if org == '*'
            octo.repositories
          else
            begin
              octo.organization_repositories(org, type: 'all')
            rescue Octokit::NotFound, Octokit::Forbidden, Octokit::Unauthorized,
              Octokit::ServerError, Octokit::TooManyRequests => e
              $loog.warn("[#{$judge}] Failed to list repos for org #{org}: #{e.class}: #{e.message}")
              octo.repositories(org)
            rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET => e
              $loog.warn("[#{$judge}] Network error listing repos for org #{org}: #{e.message}")
              octo.repositories(org)
            end
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
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.info("Repository #{repo} not found: #{e.message}")
        false
      rescue Octokit::Forbidden, Octokit::Unauthorized => e
        $loog.warn(
          "[#{$judge}] Access forbidden to #{repo} " \
          "(transient, will retry next cycle): #{e.class}: #{e.message}"
        )
        false
      rescue Octokit::TooManyRequests, Octokit::ServerError,
        Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET => e
        $loog.warn("[#{$judge}] Transient error checking #{repo}: #{e.class}: #{e.message}")
        false
      end
      raise(Fbe::Error, "No repos found matching: #{options.repositories.inspect}") if repos.empty?
      repos.shuffle!
      loog.debug("Scanning #{repos.size} repositories: #{repos.joined}...")
      repos.each do |repo|
        octo.repository(repo)
      rescue Octokit::NotFound, Octokit::Deprecated => e
        $loog.debug("[#{$judge}] Repository #{repo} not found: #{e.message}")
      rescue Octokit::Forbidden, Octokit::Unauthorized, Octokit::TooManyRequests => e
        $loog.warn("[#{$judge}] Repository #{repo} temporarily unavailable: #{e.class}: #{e.message}")
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET => e
        $loog.warn("[#{$judge}] Network error checking #{repo}: #{e.message}")
      end
      return repos unless block_given?
      repos.each do |repo|
        break if Fbe.over?(global:, options:, loog:, epoch:, kickoff:, quota_aware:, lifetime_aware:, timeout_aware:)
        yield(repo)
      end
    end
  end
end
