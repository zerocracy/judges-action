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

def skip_event(json)
  $loog.debug("The #{json[:type]} GitHub event ##{json[:id]} is ignored")
  raise Factbase::Rollback
end

def put_new_event(fact, json)
  fact.when = Time.parse(json[:created_at].iso8601)
  fact.event_type = json[:type]
  fact.event_id = json[:id].to_i
  fact.repository = json[:repo][:id].to_i
  fact.who = json[:actor][:id].to_i if json[:actor]

  case json[:type]
  when 'PushEvent'
    fact.what = 'git-was-pushed'
    fact.push_id = json[:payload][:push_id]
    skip_event(json)

  when 'IssuesEvent'
    fact.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'closed'
      fact.what = 'issue-was-closed'
    elsif json[:payload][:action] == 'opened'
      fact.what = 'issue-was-opened'
    end

  when 'IssueCommentEvent'
    fact.issue = json[:payload][:issue][:number]
    if json[:payload][:action] == 'created'
      fact.what = 'comment-was-posted'
      fact.comment_id = json[:payload][:comment][:id]
      fact.comment_body = json[:payload][:comment][:body]
      fact.who = json[:payload][:comment][:user][:id]
    end
    skip_event(json)

  when 'ReleaseEvent'
    fact.release_id = json[:payload][:release][:id]
    if json[:payload][:action] == 'published'
      fact.what = 'release-published'
      fact.who = json[:payload][:release][:author][:id]
    end

  when 'CreateEvent'
    if json[:payload][:ref_type] == 'tag'
      fact.what = 'tag-was-created'
      fact.tag = json[:payload][:ref]
    end

  else
    skip_event(json)
  end

  fact.details =
    "A new event ##{json[:id]} happened in GitHub repository #{json[:repo][:name]} " \
    "(##{json[:repo][:id]}) of type '#{json[:type]}', " \
    "with the creation time #{json[:created_at].iso8601}; " \
    'this fact must be interpreted later by other judges.'
end

# Scan one repo.
# @param [String] repo Name of the repo, like "yegor256/judges"
# @param [Integer] limit How many events to scan (if more, stop)
def one_repo(repo, limit)
  seen = 0
  repo_id = octo.repo_id_by_name(repo)
  q = "(and (eq what '#{$judge}') (eq repository #{repo_id}))"
  prev = fb.query(q).each.to_a[0]
  fb.query(q).delete!
  first = nil
  last = nil
  octo.repository_events(repo).each do |json|
    last = json[:id].to_i
    first = last if first.nil?
    if !prev.nil? && last <= prev.first_event_id
      $loog.debug(
        "No reason to scan what was scanned before: first_event_id=#{prev.first_event_id}, " \
        "prev.last_event_id=#{prev.last_event_id}, first=#{first}, last=#{last}"
      )
      break
    end
    fb.txn do |fbt|
      f = if_absent(fbt) do |n|
        put_new_event(n, json)
      end
      $loog.info("Detected new event ##{json[:id]} in #{json[:repo][:name]}: #{json[:type]}") unless f.nil?
    end
    seen += 1
    if seen >= limit
      $loog.debug("Already scanned #{seen} events in #{repo}, that's enough (>=#{limit})")
      break
    end
    break if octo.off_quota
  end
  f = fb.insert
  f.repository = repo_id
  f.first_event_id = first
  f.last_event_id = last
  f.what = $judge
  seen
end

limit = $options.max_events
limit = 1000 if limit.nil?
raise "It is impossible to scan deeper than 10,000 GitHub events, you asked for #{limit}" if limit > 10_000

repos = repositories
repos.each do |repo|
  $loog.debug("Scanning #{repo}...")
  one_repo(repo, limit / repos.size)
  break if octo.off_quota
end
