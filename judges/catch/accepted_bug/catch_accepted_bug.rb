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

$fb.query("(and (eq kind 'GitHub event')
  (eq github_action 'label-attached')
  (exists github_issue)
  (exists github_repository)
  (eq github_label 'bug'))").each do |f1|
  issue = f1.github_issue
  repo = f1.github_repository
  once($fb).query("(and (eq kind 'GitHub event')
    (eq github_action 'issue-opened')
    (eq github_issue #{issue}) (eq github_repository '#{repo}'))").each do |f2|
    n = $fb.insert
    n.kind = 'bug was accepted'
    n.time = Time.now
    n.github_reporter = f2.github_actor
    n.github_issue = issue
    n.github_repository = repo
  end
end
