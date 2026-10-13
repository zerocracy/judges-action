# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

class Fbe::FakeOctokit
  alias bare repository
  private :bare

  def list_milestones(_repo, _options = {})
    []
  end

  def repository(name)
    bare(name).merge(forks: 4, forks_count: 4)
  end
end
