# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'fbe/over'
require 'fbe/unmask_repos'
require 'joined'
require 'octokit'

module Jp
  class TerrainOctoGuard
    def initialize(
      options: $options, global: $global, loog: $loog, epoch: $epoch || Time.now, kickoff: $kickoff || Time.now,
      quota_aware: true, lifetime_aware: true, timeout_aware: true,
      octo: nil
    )
      @options = options
      @global = global
      @loog = loog
      @epoch = epoch
      @kickoff = kickoff
      @quotaaware = quota_aware
      @lifetimeaware = lifetime_aware
      @timeoutaware = timeout_aware
      @octo = octo || Fbe.octo(loog: @loog, global: @global, options: @options)
    end

    def eachrepo
      return if over?
      found = repos
      @loog.debug("Scanning #{found.size} repositories: #{found.joined}...")
      found.each do |repo|
        break if over?
        yield(repo)
      end
    end

    def repository(repo)
      safe(repo, 'repository') { @octo.repository(repo) }
    end

    def releases(repo)
      safe(repo, 'releases') { @octo.releases(repo) }
    end

    def contributors(repo)
      safe(repo, 'contributors') { @octo.contributors(repo) }
    end

    def tree(repo, branch)
      safe(repo, 'tree') { @octo.tree(repo, branch, recursive: true) }
    end

    def searchcommits(repo, since)
      safe(repo, 'commit search') { @octo.search_commits("repo:#{repo} author-date:>#{since}") }
    end

    private

    def repos
      raise(Fbe::Error, 'Repositories mask is not specified') unless @options.repositories
      raise(Fbe::Error, 'Repositories mask is empty') if @options.repositories.empty?
      masks = (@options.repositories || '').split(',')
      found = included(masks)
      exclude!(found, masks)
      raise(Fbe::Error, "No repos found matching: #{@options.repositories.inspect}") if found.empty?
      found.reject! do |repo|
        json = repository(repo)
        json.nil? || json[:archived]
      end
      found.shuffle
    end

    def included(masks)
      found = []
      masks.reject { |m| m.start_with?('-') }.each do |mask|
        unless mask.include?('*')
          found << mask
          next
        end
        re = Fbe.mask_to_regex(mask)
        list = masked(mask)
        next if list.nil?
        list.each { |repo| found << repo[:full_name] if re.match?(repo[:full_name]) }
      end
      found
    end

    def exclude!(found, masks)
      masks.select { |m| m.start_with?('-') }.each do |mask|
        re = Fbe.mask_to_regex(mask[1..])
        found.reject! { |repo| re.match?(repo) }
      end
    end

    def masked(mask)
      org = mask.split('/')[0]
      begin
        @octo.organization_repositories(org, type: 'all')
      rescue Octokit::NotFound
        safe(org, 'repositories') { @octo.repositories(org) }
      rescue Octokit::Deprecated => e
        info(org, 'organization repositories', e)
        nil
      rescue Octokit::Forbidden => e
        warning(org, 'organization repositories', e)
        nil
      end
    end

    def safe(repo, action)
      yield
    rescue Octokit::NotFound, Octokit::Deprecated => e
      info(repo, action, e)
      nil
    rescue Octokit::Forbidden => e
      warning(repo, action, e)
      nil
    end

    def over?
      Fbe.over?(
        global: @global, options: @options, loog: @loog, epoch: @epoch, kickoff: @kickoff,
        quota_aware: @quotaaware, lifetime_aware: @lifetimeaware, timeout_aware: @timeoutaware
      )
    end

    def info(repo, action, error)
      @loog.info("[#{$judge}] The #{action} for #{repo} is not accessible: #{error.class}: #{error.message}")
    end

    def warning(repo, action, error)
      @loog.warn(
        "[#{$judge}] Access forbidden to #{action} for #{repo} " \
        "(transient, will retry next cycle): #{error.class}: #{error.message}"
      )
    end
  end
end
