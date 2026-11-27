# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe'
require 'fbe/octo'
require 'octokit'
require_relative '../../lib/slug'
require_relative '../test__helper'

class TestSlug < Jp::Test
  def test_answers_the_name_of_the_repository
    seed = Random.new_seed
    name = "foo/#{Random.new(seed).bytes(6).unpack1('H*')}-ёж"
    octo = Object.new
    octo.define_singleton_method(:repo_name_by_id) { |_id| name }
    Fbe.stub(:octo, octo) do
      assert_equal(name, Jp.slug(42), "repository name with seed #{seed} is not the one GitHub gave")
    end
  end

  def test_raises_not_found_that_fbe_wrapped
    octo = Object.new
    octo.define_singleton_method(:repo_name_by_id) do |id|
      raise(Octokit::NotFound.new(method: :get, url: "https://api.github.com/repositories/#{id}", status: 404))
    rescue Octokit::NotFound => e
      raise(Fbe::Error, "GitHub repository ##{id} is not accessible: #{e.message}")
    end
    Fbe.stub(:octo, octo) do
      assert_raises(Octokit::NotFound, 'wrapped 404 does not reach the rescue of the judge') { Jp.slug(42) }
    end
  end

  def test_raises_forbidden_that_fbe_wrapped
    octo = Object.new
    octo.define_singleton_method(:repo_name_by_id) do |id|
      raise(Octokit::Forbidden.new(method: :get, url: "https://api.github.com/repositories/#{id}", status: 403))
    rescue Octokit::Forbidden => e
      raise(Fbe::Error, "GitHub repository ##{id} is not accessible: #{e.message}")
    end
    Fbe.stub(:octo, octo) do
      assert_raises(Octokit::Forbidden, 'wrapped 403 does not reach the rescue of the judge') { Jp.slug(42) }
    end
  end

  def test_keeps_fbe_error_without_cause
    octo = Object.new
    octo.define_singleton_method(:repo_name_by_id) { |id| raise(Fbe::Error, "No repository ##{id}") }
    Fbe.stub(:octo, octo) do
      assert_raises(Fbe::Error, 'error with no cause is lost on its way up') { Jp.slug(42) }
    end
  end
end
