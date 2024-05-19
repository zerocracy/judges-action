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

def put_new_github_event(json)
  n = fb.insert
  n.kind = 'GitHub event'

  case json[:type]
  when 'PushEvent'
    n.github_action = 'push'
    n.github_push_id = json[:payload][:push_id]

  when 'IssuesEvent'
    n.github_issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'closed'
      n.github_action = 'issue-closed'
    elsif json[:payload][:action] == 'opened'
      n.github_action = 'issue-opened'
    end

  when 'IssueCommentEvent'
    n.github_issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'created'
      n.github_action = 'comment-posted'
      n.github_comment_id = json[:payload][:comment][:id]
      n.github_comment_body = json[:payload][:comment][:body]
      n.github_comment_author = json[:payload][:comment][:user][:login]
      n.github_comment_author_id = json[:payload][:comment][:user][:id]
    end

  when 'ReleaseEvent'
    n.github_release_id = json[:payload][:release][:id]
    if json[:payload][:action] == 'published'
      n.github_action = 'release-published'
      n.github_release_author = json[:payload][:release][:author][:login]
      n.github_release_author_id = json[:payload][:release][:author][:id]
    end

  when 'CreateEvent'
    if json[:payload][:ref_type] == 'tag'
      n.github_action = 'tag-created'
      n.github_tag = json[:payload][:ref]
    end
  end
  n.time = Time.parse(json[:created_at].iso8601)
  n.github_event_type = json[:type]
  n.github_event_id = json[:id]
  n.github_repository = json[:repo][:name]
  n.github_repository_id = json[:repo][:id]
  n.github_actor = json[:actor][:login] if json[:actor]
  n.github_actor_id = json[:actor][:id] if json[:actor]
end

seen = 0
catch :stop do
  each_repo do |repo|
    octo.repository_events(repo).each do |json|
      next unless fb.query("(eq github_event_id #{json[:id]})").each.to_a.empty?
      $loog.info("Detected new event ##{json[:id]} in #{json[:repo][:name]}: #{json[:type]}")
      put_new_github_event(json)
      seen += 1
      if !$options.github_max_events.nil? && seen >= $options.github_max_events
        $loog.info("Already scanned #{seen} events, that's enough (due to 'github_max_events' option)")
        throw :stop
      end
      throw :stop if octo.off_quota
    end
  end
end
