# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'factbase'
require_relative '../test__helper'

class TestAddReviewComments < Jp::Test
  def test_sets_review_comments_when_missing
    pl = { id: 93, comments: 2 }
    repo = 42
    stub(repo, pl)
    what = 'pull-was-reviewed'
    fb = Factbase.new
    fact = fb.insert
    fact.what = what
    fact.issue = pl[:id]
    fact.repository = repo
    fact.where = 'github'
    VCR.use_cassette('add-review-comments/sets-review-comments-when-missing') do
      load_it('add-review-comments', fb)
    end
    facts = fb.query("(eq what \"#{what}\")").each.to_a
    assert_equal(pl[:id], facts.first.issue)
    assert_equal(2, facts.first.review_comments)
  end

  def test_does_not_overwrite_existing_review_comments
    pl = { id: 93, comments: 2 }
    repo = 42
    stub(repo, pl)
    what = 'pull-was-reviewed'
    fb = Factbase.new
    fact = fb.insert
    fact.what = what
    fact.issue = pl[:id]
    fact.repository = repo
    fact.where = 'github'
    fact.review_comments = 1
    VCR.use_cassette('add-review-comments/does-not-overwrite-existing-review-comments') do
      load_it('add-review-comments', fb)
    end
    facts = fb.query("(eq what \"#{what}\")").each.to_a
    assert_equal(pl[:id], facts.first.issue)
    assert_equal(1, facts.first.review_comments)
  end

  def test_adds_review_comments_to_facts_without_review_comments
    pulls = [{ id: 93, comments: 2 }, { id: 94, comments: 1 }, { id: 95, comments: 4 }]
    repo = 42
    stub(repo, *pulls)
    what = 'pull-was-reviewed'
    fb = Factbase.new
    pulls.each do |pl|
      fact = fb.insert
      fact.what = what
      fact.issue = pl[:id]
      fact.repository = repo
      fact.where = 'github'
    end
    VCR.use_cassette('add-review-comments/adds-review-comments-to-facts-without-review-comments') do
      load_it('add-review-comments', fb)
    end
    facts = fb.query("(eq what \"#{what}\")").each.to_a
    facts.each do |f|
      assert_equal(pulls.find { |pl| pl[:id] == f.issue }[:comments], f.review_comments)
    end
  end

  def test_handles_not_found_repo
    pl = { id: 93, comments: 2 }
    repo = 90
    stub(repo, pl)
    what = 'pull-was-reviewed'
    fb = Factbase.new
    fact = fb.insert
    fact.what = what
    fact.issue = pl[:id]
    fact.repository = repo
    fact.where = 'github'
    VCR.use_cassette('add-review-comments/handles-not-found-repo') do
      load_it('add-review-comments', fb)
    end
    facts = fb.query("(eq what '#{what}')").each.to_a
    assert_equal(pl[:id], facts.first.issue)
    assert_nil(facts.first['review_comments'])
  end

  def test_rescues_forbidden_on_repo_lookup
    rate_limit_up
    fb = Factbase.new
    fact = fb.insert
    fact.what = 'pull-was-reviewed'
    fact.issue = 44
    fact.repository = 42
    fact.where = 'github'
    VCR.use_cassette('add-review-comments/rescues-forbidden-on-repo-lookup') do
      load_it('add-review-comments', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(
      f['stale'],
      '403 is transient — seed fact must NOT be marked stale=repository; next cycle will retry the repo lookup'
    )
  end

  def test_rescues_forbidden_on_pull_request_lookup
    rate_limit_up
    fb = Factbase.new
    fact = fb.insert
    fact.what = 'pull-was-reviewed'
    fact.issue = 44
    fact.repository = 42
    fact.where = 'github'
    VCR.use_cassette('add-review-comments/rescues-forbidden-on-pull-request-lookup') do
      load_it('add-review-comments', fb)
    end
    f = fb.query('(eq issue 44)').each.first
    refute_nil(f)
    assert_nil(f['stale'], '403 is transient — fact must NOT be marked stale; pull lookup will retry next cycle')
  end

  def stub(repo, *pulls)
    pulls.each do |pl|
      stub_github(
        "https://api.github.com/repos/foo/foo/pulls/#{pl[:id]}",
        body: {
          default_branch: 'master',
          additions: 1,
          deletions: 1,
          comments: 1,
          review_comments: pl[:comments],
          commits: 2,
          changed_files: 3
        }
      )
    end
    stub_github(
      "https://api.github.com/repositories/#{repo}",
      status: repo == 90 ? 404 : 200,
      body: { id: 820_463_873, name: 'foo', full_name: 'foo/foo' }
    )
    stub_github(
      'https://api.github.com/rate_limit',
      body: {
        rate: { limit: 600, remaining: 590, reset: 1_728_464_472, used: 1, resource: 'core' }
      }
    )
  end
end
