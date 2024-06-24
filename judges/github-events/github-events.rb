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

iterate do
  as 'events-were-scanned'
  by '(plus 0 $before)'
  quota_aware
  limit 1

  def self.skip_event(json)
    $loog.debug(
      "The #{json[:type]} GitHub event ##{json[:id]} " \
      "in #{json[:repo][:name]} is ignored"
    )
    raise Factbase::Rollback
  end

  def self.put_new_event(fact, json)
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

  over do |repository, latest|
    id = nil
    total = 0
    detected = 0
    octo.repository_events(repository).each_with_index do |json, idx|
      if idx >= $options.max_events
        $loog.debug("Have already scanned #{idx} events, it's time to stop")
        break
      end
      total += 1
      id = json[:id].to_i
      if id < latest
        $loog.debug("The event ID ##{id} is smaller than the latest ##{latest}, time to stop")
        break
      end
      fb.txn do |fbt|
        f = if_absent(fbt) do |n|
          put_new_event(n, json)
        end
        unless f.nil?
          $loog.info("Detected new event ##{id} (no.#{idx}) in #{json[:repo][:name]}: #{json[:type]}")
          detected += 1
        end
      end
    end
    $loog.info(
      "In #{octo.repo_name_by_id(repository)}, " \
      "detected #{detected} events out of #{total} scanned"
    )
    id
  end
end
