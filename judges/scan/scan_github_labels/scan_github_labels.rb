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

detect = %w[bug enhancement question]

found = 0
catch :stop do
  each_repo do |repo|
    octo.through_pages(:search_issues, "repo:#{repo} label:#{detect.join(',')}") do |page|
      page[:items].each do |e|
        $loog.debug("Issue #{repo}##{e[:number]} found with [#{e[:labels].map { |l| l[:name] }.join(', ')}]")
        e[:labels].each do |label|
          next unless detect.include?(label[:name])
          found += 1
          n = if_absent(fb) do |f|
            f.repository = find_repo_id(repo)
            f.issue = e[:number]
            f.label = label[:name]
            f.what = 'label-attached'
          end
          next if n.nil?
          octo.through_pages(:issue_timeline, repo, e[:number]) do |pp|
            pp.each do |te|
              next unless te[:event] == 'labeled'
              next unless te[:label][:name] == label[:name]
              n.who = te[:actor][:id]
              n.when = te[:created_at]
              throw :break
            end
          end
          n.details =
            "The '##{n.label}' label was attached by ##{n.who} " \
            "to the issue #{repo}##{n.issue} at #{n.when}, which may trigger future judges."
          $loog.info("Detected '##{n.label}' at #{repo}##{e[:number]}, attached by ##{n.who}")
          throw :stop if octo.off_quota
        end
        if !$options.max_labels.nil? && found >= $options.max_labels
          $loog.info("Already found #{found} labels, that's enough (due to 'max_labels' option)")
          throw :stop
        end
      end
    end
  end
end
