# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'octokit'
require_relative 'fake_github'
require_relative 'test__helper'

class TestFakeGithub < Jp::Test
  def test_serves_array_body
    seed = Random.new_seed
    number = Random.new(seed).rand(1_000_000)
    Jp::FakeGithub.new(
      'GET /repos/foo/foo/releases' => [{ id: number, name: 'Ω первый' }]
    ).run do
      assert_equal(
        number, Octokit::Client.new.releases('foo/foo').first[:id],
        "the array body did not reach the client as the single release declared, seed #{seed}"
      )
    end
  end

  def test_serves_array_body_of_several_items
    seed = Random.new_seed
    random = Random.new(seed)
    numbers = [random.rand(1_000_000), random.rand(1_000_000)]
    Jp::FakeGithub.new(
      'GET /repos/foo/foo/releases' => [{ id: numbers.first, name: '' }, { id: numbers.last, name: 'Ω' }]
    ).run do
      assert_equal(
        numbers, Octokit::Client.new.releases('foo/foo').map { |release| release[:id] },
        "the array body of two releases did not reach the client in the order declared, seed #{seed}"
      )
    end
  end

  def test_serves_empty_array_body
    Jp::FakeGithub.new(
      'GET /repos/foo/foo/releases' => []
    ).run do
      assert_empty(
        Octokit::Client.new.releases('foo/foo'),
        'the empty array body did not reach the client as an empty list of releases'
      )
    end
  end

  def test_serves_status_paired_with_array_body
    seed = Random.new_seed
    number = Random.new(seed).rand(1_000_000)
    Jp::FakeGithub.new(
      'GET /repos/foo/foo/releases' => [200, [{ id: number, name: '' }]]
    ).run do
      assert_equal(
        number, Octokit::Client.new.releases('foo/foo').first[:id],
        "the status paired with an array body did not reach the client as the release declared, seed #{seed}"
      )
    end
  end

  def test_serves_hash_body
    seed = Random.new_seed
    number = Random.new(seed).rand(1_000_000)
    Jp::FakeGithub.new(
      'GET /repos/foo/foo' => { id: number, full_name: 'foo/foo' }
    ).run do
      assert_equal(
        number, Octokit::Client.new.repository('foo/foo')[:id],
        "the hash body did not reach the client as the repository declared, seed #{seed}"
      )
    end
  end
end
