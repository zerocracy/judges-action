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

def put_new_event(json)
  n = fb.insert
  n.kind = 'github-event'
  n.time = Time.parse(json[:created_at].iso8601)
  n.event_type = json[:type]
  n.event_id = json[:id]
  n.repository = json[:repo][:name]
  n.repository_id = json[:repo][:id]
  n.actor = json[:actor][:login] if json[:actor]
  n.actor_id = json[:actor][:id] if json[:actor]

  case json[:type]
  when 'PushEvent'
    n.action = 'push'
    n.push_id = json[:payload][:push_id]

  when 'IssuesEvent'
    n.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'closed'
      n.action = 'issue-closed'
    elsif json[:payload][:action] == 'opened'
      n.action = 'issue-opened'
    end

  when 'IssueCommentEvent'
    n.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'created'
      n.action = 'comment-posted'
      n.comment_id = json[:payload][:comment][:id]
      n.comment_body = json[:payload][:comment][:body]
      n.comment_author = json[:payload][:comment][:user][:login]
      n.comment_author_id = json[:payload][:comment][:user][:id]
    end

  when 'ReleaseEvent'
    n.release_id = json[:payload][:release][:id]
    if json[:payload][:action] == 'published'
      n.action = 'release-published'
      n.release_author = json[:payload][:release][:author][:login]
      n.release_author_id = json[:payload][:release][:author][:id]
    end

  when 'CreateEvent'
    if json[:payload][:ref_type] == 'tag'
      n.action = 'tag-created'
      n.tag = json[:payload][:ref]
    end
  end
end

seen = 0
catch :stop do
  each_repo do |repo|
    octo.repository_events(repo).each do |json|
      next unless fb.query("(eq event_id #{json[:id]})").each.to_a.empty?
      $loog.info("Detected new event ##{json[:id]} in #{json[:repo][:name]}: #{json[:type]}")
      put_new_event(json)
      seen += 1
      if !$options.max_events.nil? && seen >= $options.max_events
        $loog.info("Already scanned #{seen} events, that's enough (due to 'max_events' option)")
        throw :stop
      end
      throw :stop if octo.off_quota
    end
  end
end
