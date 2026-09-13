# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

class Fbe::FakeOctokit
  unless method_defined?(:orig_repository)
    alias_method :orig_repository, :repository
  end

  def repository(name)
    h = orig_repository(name)
    h[:forks] = 1
    h[:forks_count] = 1
    h
  end

  def list_milestones(_repo, _options = {})
    []
  end
end
