# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'

class TestIssueWasClosedWording < Jp::Test
  def test_writes_the_same_details_as_the_other_judge
    root = File.expand_path('../..', __dir__)
    texts =
      %w[issue-was-closed label-was-attached].map do |judge|
        body = File.read(File.join(root, 'judges', judge, "#{judge}.rb"))
        body[/"[^"]*label was attached by[^"]*"/]
      end
    refute_includes(texts, nil, 'both judges must write a label attachment text')
    assert_equal(texts[1], texts[0], 'two judges that make the same fact cannot word it differently')
  end
end
