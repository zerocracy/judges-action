# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

class Fbe::FakeOctokit
  def get(path)
    raise(Fbe::Error, "Unsupported fake API endpoint: #{path}") unless path == '/rate_limit'
    { resources: { search: { remaining: 30, limit: 30 } } }
  end

  def list_milestones(_repo, _options = {})
    []
  end
end
