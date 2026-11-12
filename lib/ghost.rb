# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'jp'

# GitHub's shared placeholder for deleted accounts: https://api.github.com/users/ghost.
def Jp.ghost?(id)
  id == 10_137
end
