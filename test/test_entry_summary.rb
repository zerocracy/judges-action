# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'test__helper'

class TestEntrySummary < Jp::Test
  def test_deletes_the_summary_after_the_factbase_is_pulled
    body = File.read(File.join(File.expand_path('..', __dir__), 'entry.sh'))
    deletion = body.index("judges-summary')\\\").delete!")
    refute_nil(deletion, 'entry.sh must delete the summary facts somewhere')
    pull = body.index(/^\s*\$\{JUDGES\} "\$\{gopts\[@\]\}" pull/)
    refute_nil(pull, 'entry.sh must pull the factbase somewhere')
    assert_operator(
      deletion, :>, pull,
      'the summary is deleted before the pull overwrites the same file, so the deletion is lost'
    )
  end
end
