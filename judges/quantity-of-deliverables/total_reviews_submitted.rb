# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/github_graph'
require 'fbe/octo'
require 'fbe/unmask_repos'
require_relative '../../lib/humans'
require_relative '../../lib/patches/unmask_repos'

def total_reviews_submitted(fact)
  total = 0
  Fbe.unmask_repos.each do |repo|
    owner, name = repo.split('/')
    count = 0
    cursor = nil
    queue = []
    loop do
      json = Fbe.github_graph.pull_requests_with_reviews(owner, name, fact.since, cursor:)
      json['pulls_with_reviews'].each do |p|
        queue.push([p['number'], nil])
      end
      break unless json['has_next_page']
      cursor = json['next_cursor']
    end
    until queue.empty?
      batch = queue.shift(10)
      pulls = Fbe.github_graph.pull_request_reviews(owner, name, pulls: batch)
      authors = authors(owner, name, batch)
      window = ->(r) { r['submitted_at'] > fact.since && r['submitted_at'] <= fact.when }
      count +=
        pulls.sum do |pull|
          pull['reviews'].count do |review|
            author = review['author'] || authors[review['id']]
            window.call(review) && Jp.human?(author&.dig('login'), author&.dig('__typename') || author&.dig('type'))
          end
        end
      pulls.select { _1['reviews_has_next_page'] }.each do |p|
        queue.push([p['number'], p['reviews_next_cursor']])
      end
    end
    total += count
  rescue Octokit::NotFound, Octokit::Deprecated => e
    $loog.info("Can't count submitted reviews in #{repo}, #{count} of them dropped: #{e.message}")
  rescue Octokit::Forbidden => e
    $loog.warn(
      "[#{$judge}] Access forbidden to submitted reviews in #{repo}, #{count} of them dropped " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
  rescue GraphQL::Client::Error,
    Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    $loog.warn(
      "[#{$judge}] Can't count submitted reviews in #{repo}, #{count} of them dropped " \
      "(transient, will retry next cycle): #{e.class}: #{e.message}"
    )
  end
  { total_reviews_submitted: total }
end

def authors(owner, name, batch)
  data =
    Fbe.github_graph.query(
      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            #{batch.map { |number, cursor| request(number, cursor) }.join("\n")}
          }
        }
      GRAPHQL
    )&.to_h&.dig('repository')
  return {} if data.nil?
  data.each_with_object({}) do |(_key, pull), map|
    pull&.dig('reviews', 'nodes')&.each { |review| map[review['id']] = review['author'] }
  end
end

def request(number, cursor)
  after = "after: \"#{cursor}\", " unless cursor.nil?
  <<~GRAPHQL
    pr_#{number}: pullRequest(number: #{number}) {
      reviews(#{after}first: 100) {
        nodes {
          id
          author {
            login
            __typename
          }
        }
      }
    }
  GRAPHQL
end
