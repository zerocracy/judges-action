# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Counts comments
class Judges::Comments
  def initialize(octo:, pull_request:)
    @octo = octo
    @pull_request = pull_request
    @code_comments = @octo.pull_request_comments(@pull_request[:base][:repo][:full_name], @pull_request[:number])
    @issue_comments = @octo.issue_comments(@pull_request[:base][:repo][:full_name], @pull_request[:number])
  end

  def total
    @pull_request[:comments] + @pull_request[:review_comments]
  end

  def to_code
    @code_comments.count
  end

  def by_author
    @issue_comments.count { |comment| comment[:user][:id] == @pull_request[:user][:id] }
  end

  def by_reviewers
    @code_comments.count { |comment| comment[:user][:id] != @pull_request[:user][:id] }
  end

  def appreciated
    appreciated = 0
    @issue_comments.each do |comment|
      appreciated += Fbe.octo.issue_comment_reactions(@pull_request[:base][:repo][:full_name], comment[:id])
        .count { |reaction| comment[:user][:id] != reaction[:user][:id] }
    end
    appreciated
  end
end
