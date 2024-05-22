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

catch :stop do
  each_repo do |repo|
    octo.search_issues("repo:#{repo} label:bug,enhancement,question")[:items].each do |e|
      e[:labels].each do |label|
        n = if_absent(fb) do |f|
          f.repository = find_repo_id(repo)
          f.issue = e[:number]
          f.label = label[:name]
          f.what = 'label-attached'
        end
        next if n.nil?
        n.details =
          "The '#{n.label}' label was attached to the issue ##{n.issue} " \
          'by someone (GitHub API doesn\'t provide this information) some time ago ' \
          '(this information also is not available).'
        # @todo #1:30min n.when -- let's find out when the label was attached
        $loog.info("Detected new label '##{label[:name]}' at #{repo}##{e[:number]}")
        throw :stop if octo.off_quota
      end
    end
  end
end
