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

require 'octokit'

octokit = Octokit::Client.new
unless $options.github_token.nil?
  token = $options.github_token
  octokit = Octokit::Client.new(access_token: token)
  $loog.info("Accessing GitHub with a token (#{token.length} chars)")
end

seen = 0
octokit.repository_events($options.github_repository).each do |e|
  next unless $fb.query("(eq github_event_id #{e[:id]})").extend(Enumerable).to_a.empty?
  $loog.info("Detected new event ##{e[:id]} in #{e[:repo][:name]}: #{e[:type]}")
  n = $fb.insert
  n.kind = 'GitHub event'
  n.time = e[:created_at].iso8601
  n.github_event_type = e[:type]
  n.github_event_id = e[:id]
  n.github_repository = e[:repo][:name]
  n.github_repository_id = e[:repo][:id]
  n.github_action = e[:payload][:type] if e[:payload][:type]
  n.github_actor = e[:actor][:login] if e[:actor]
  n.github_actor_id = e[:actor][:id] if e[:actor]
  if e[:type] == 'PushEvent'
    n.github_push_id = e[:payload][:push_id]
  end
  seen += 1
  if !$options.github_max_events.nil? && seen >= $options.github_max_events
    $loog.info("Already scanned #{seen} events, that's enough (due to 'github_max_events' option)")
    break
  end
  if octokit.rate_limit.remaining < 10
    $loog.info("To much GitHub API quota consumed already, stopping")
    break
  end
end
