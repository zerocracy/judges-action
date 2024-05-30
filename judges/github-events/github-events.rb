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

def put_new_event(fbt, json)
  n = fbt.insert
  n.when = Time.parse(json[:created_at].iso8601)
  n.event_type = json[:type]
  n.event_id = json[:id].to_i
  n.repository = json[:repo][:id].to_i
  n.who = json[:actor][:id].to_i if json[:actor]

  case json[:type]
  when 'PushEvent'
    n.what = 'git-was-pushed'
    n.push_id = json[:payload][:push_id]

  when 'IssuesEvent'
    n.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'closed'
      n.what = 'issue-was-closed'
    elsif json[:payload][:action] == 'opened'
      n.what = 'issue-was-opened'
    end

  when 'IssueCommentEvent'
    n.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'created'
      n.what = 'comment-was-posted'
      n.comment_id = json[:payload][:comment][:id]
      n.comment_body = json[:payload][:comment][:body]
      n.who = json[:payload][:comment][:user][:id]
    end

  when 'ReleaseEvent'
    n.release_id = json[:payload][:release][:id]
    if json[:payload][:action] == 'published'
      n.what = 'release-published'
      n.who = json[:payload][:release][:author][:id]
    end

  when 'CreateEvent'
    if json[:payload][:ref_type] == 'tag'
      n.what = 'tag-was-created'
      n.tag = json[:payload][:ref]
    end
  end

  n.details =
    "A new event ##{json[:id]} happened in GitHub #{json[:repo][:name]} repository " \
    "(id: #{json[:repo][:id]}) of type '#{json[:type]}', " \
    "with the creation time #{json[:created_at].iso8601}."
end

def one_repo(repo, seen)
  catch :stop do
    # Taking the largest ID of GitHub event that was seen so far:
    largest = fb.query(
      "(eq event_id
        (agg (eq repository #{octo.repo_id_by_name(repo)})
        (max event_id)))"
    ).each.to_a[0]
    unless largest.nil?
      largest = largest.event_id
      $loog.debug("The largest ID we've seen so far is #{largest} (everything below this number will be ignored)")
    end
    octo.repository_events(repo).each do |json|
      unless fb.query("(eq event_id #{json[:id]})").each.to_a.empty?
        $loog.debug("The event ##{json[:id]} (#{json[:type]}) has already been seen, skipping")
        next
      end
      if largest && json[:id].to_i <= largest
        $loog.debug("The event ##{json[:id]} (#{json[:type]}) is below the largest ID #{largest}, skipping")
        throw :stop
      end
      $loog.info("Detected new event ##{json[:id]} in #{json[:repo][:name]}: #{json[:type]}")
      fb.txn do |fbt|
        put_new_event(fbt, json)
      end
      seen += 1
      if !$options.max_events.nil? && seen >= $options.max_events
        $loog.debug("Already scanned #{seen} events, that's enough (due to 'max_events' option)")
        throw :stop
      end
      throw :alarm if octo.off_quota
    end
  end
  seen
end

seen = 0
catch :alarm do
  each_repo do |repo|
    seen += one_repo(repo, seen)
  end
end
