# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/over'
require 'fbe/unmask_repos'
require 'joined'
require 'octokit'

module TerrainOcto
  def self.safe(repo, action)
    yield
  rescue Octokit::NotFound, Octokit::Deprecated => e
    info(repo, action, e)
    nil
  rescue Octokit::Forbidden => e
    warning(repo, action, e)
    nil
  end

  def self.repos(
    options: $options, global: $global, loog: $loog, epoch: $epoch || Time.now, kickoff: $kickoff || Time.now,
    quota_aware: true, lifetime_aware: true, timeout_aware: true
  )
    raise(Fbe::Error, 'Repositories mask is not specified') unless options.repositories
    raise(Fbe::Error, 'Repositories mask is empty') if options.repositories.empty?
    return if block_given? && Fbe.over?(
      global:, options:, loog:, epoch:, kickoff:, quota_aware:, lifetime_aware:, timeout_aware:
    )
    found = list(options:, global:, loog:)
    loog.debug("Scanning #{found.size} repositories: #{found.joined}...")
    return found unless block_given?
    found.each do |repo|
      break if Fbe.over?(global:, options:, loog:, epoch:, kickoff:, quota_aware:, lifetime_aware:, timeout_aware:)
      yield(repo)
    end
  end

  def self.list(options:, global:, loog:)
    octo = Fbe.octo(loog:, global:, options:)
    masks = (options.repositories || '').split(',')
    found = included(masks, octo)
    exclude!(found, masks)
    raise(Fbe::Error, "No repos found matching: #{options.repositories.inspect}") if found.empty?
    found.reject! do |repo|
      json = safe(repo, 'repository') { octo.repository(repo) }
      json.nil? || json[:archived]
    end
    found.shuffle
  end

  def self.included(masks, octo)
    found = []
    masks.reject { |m| m.start_with?('-') }.each do |mask|
      unless mask.include?('*')
        found << mask
        next
      end
      re = Fbe.mask_to_regex(mask)
      list = masked(mask, octo)
      next if list.nil?
      list.each { |repo| found << repo[:full_name] if re.match?(repo[:full_name]) }
    end
    found
  end

  def self.exclude!(found, masks)
    masks.select { |m| m.start_with?('-') }.each do |mask|
      re = Fbe.mask_to_regex(mask[1..])
      found.reject! { |repo| re.match?(repo) }
    end
  end

  def self.masked(mask, octo)
    org = mask.split('/')[0]
    begin
      octo.organization_repositories(org, type: 'all')
    rescue Octokit::NotFound
      safe(org, 'repositories') { octo.repositories(org) }
    rescue Octokit::Deprecated => e
      info(org, 'organization repositories', e)
      nil
    rescue Octokit::Forbidden => e
      warning(org, 'organization repositories', e)
      nil
    end
  end

  def self.info(repo, action, error)
    $loog.info("[#{$judge}] The #{action} for #{repo} is not accessible: #{error.class}: #{error.message}")
  end

  def self.warning(repo, action, error)
    $loog.warn(
      "[#{$judge}] Access forbidden to #{action} for #{repo} " \
      "(transient, will retry next cycle): #{error.class}: #{error.message}"
    )
  end
end
