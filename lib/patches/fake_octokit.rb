# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'

class Fbe::FakeOctokit
  def list_milestones(_repo, **)
    []
  end
end
