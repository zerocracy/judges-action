# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

if Object.const_defined?('Fbe::FakeOctokit')
  Fbe::FakeOctokit.class_eval do
    def list_milestones(repo, _options = {})
      $loog.info("FakeOctokit#list_milestones(#{repo}) called — returning []")
      []
    end
  end
end
