# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fbe/octo'
require 'time'

class Fbe::FakeOctokit
  def list_milestones(repo, options = {})
    all = [
      {
        id: 9_284_531, number: 1, state: 'open', title: 'First release',
        description: 'The first one', creator: { login: 'yegor256', id: 526_301, type: 'User' },
        open_issues: 3, closed_issues: 7,
        created_at: Time.parse('2024-07-11 20:35:25 UTC'),
        updated_at: Time.parse('2024-08-11 20:35:25 UTC'),
        due_on: Time.parse('2024-09-11 20:35:25 UTC'),
        closed_at: nil, html_url: "https://github.com/#{repo}/milestone/1"
      },
      {
        id: 9_284_532, number: 2, state: 'closed', title: 'Second release',
        description: 'The second one', creator: { login: 'yegor256', id: 526_301, type: 'User' },
        open_issues: 0, closed_issues: 12,
        created_at: Time.parse('2024-08-12 20:35:25 UTC'),
        updated_at: Time.parse('2024-09-12 20:35:25 UTC'),
        due_on: nil,
        closed_at: Time.parse('2024-09-12 20:35:25 UTC'), html_url: "https://github.com/#{repo}/milestone/2"
      }
    ]
    state = options[:state] || options['state'] || 'open'
    return all if state.to_s == 'all'
    all.select { |m| m[:state] == state.to_s }
  end
end
