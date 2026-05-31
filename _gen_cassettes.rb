# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require 'fileutils'

def interaction(method, uri, status, body,
headers = { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' })
  {
    'request' => {
      'method' => method, 'uri' => uri,
      'body' => { 'encoding' => 'UTF-8', 'string' => '' },
      'headers' => {}
    },
    'response' => {
      'status' => { 'code' => status, 'message' => '' },
      'headers' => headers.transform_values { |v| [v] },
      'body' => { 'encoding' => 'UTF-8', 'string' => body },
      'http_version' => '1.1'
    },
    'recorded_at' => 'Mon, 01 Jan 2024 00:00:00 GMT'
  }
end

def write_cassette(dir, name, interactions)
  File.write(File.join(dir, "#{name}.yml"), { 'http_interactions' => interactions }.to_yaml)
  puts("  #{name}.yml (#{interactions.size} interactions)")
end

BASE = 'https://api.github.com'
REPO = '{"id":42,"full_name":"foo/foo"}'

def prefix
  [
    interaction(:get, "#{BASE}/repos/foo/foo", 200, REPO),
    interaction(:get, "#{BASE}/repositories/42", 200, REPO)
  ]
end

not_found = '{"message":"Not Found","documentation_url":"https://docs.github.com","status":"404"}'
forbidden = '{"message":"Resource not accessible by integration"}'

dir = 'test/vcr_cassettes/type-was-attached'
FileUtils.mkdir_p(dir)
puts "\ntype-was-attached:"

timeline_orphan = '[{"id":100,"event":"issue_type_added","node_id":"ITAE_orphan_actor","created_at":"2025-09-30 06:14:38 UTC"}]'
write_cassette(dir, 'marks_stale_when_timeline_returns_not_found', prefix + [
  interaction(:get, "#{BASE}/repos/foo/foo/issues/44/timeline?per_page=100", 404, not_found)
])
write_cassette(dir, 'rescues_forbidden_on_timeline_lookup', prefix + [
  interaction(:get, "#{BASE}/repos/foo/foo/issues/44/timeline?per_page=100", 403, forbidden)
])
write_cassette(dir, 'marks_stale_when_graphql_actor_is_nil', prefix + [
  interaction(:get, "#{BASE}/repos/foo/foo/issues/44/timeline?per_page=100", 200, timeline_orphan)
])

dir = 'test/vcr_cassettes/issue-was-opened'
FileUtils.mkdir_p(dir)
puts "\nissue-was-opened:"

write_cassette(dir, 'rescues_forbidden_on_issue_lookup', prefix + [
  interaction(:get, "#{BASE}/repos/foo/foo/issues/44", 403, forbidden)
])
