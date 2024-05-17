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

require 'obk'
require 'octokit'
require_relative 'octo/fake_octokit'

def octo
  $global[:octo] ||= begin
    if $options.testing.nil?
      o = Octokit::Client.new
      if $options.github_token.nil?
        $loog.warn('Accessing GitHub API without a token!')
      else
        token = $options.github_token
        o = Octokit::Client.new(access_token: token)
        $loog.info("Accessing GitHub API with a token (#{token.length} chars)")
      end
      o = Obk.new(o, pause: 1000)
    else
      o = FakeOctokit.new
    end
    def o.off_quota
      left = rate_limit.remaining
      if left < 5
        $loog.info("To much GitHub API quota consumed already (remaining=#{left}), stopping")
        true
      else
        false
      end
    end
    o
  end
  $global[:octo]
end
