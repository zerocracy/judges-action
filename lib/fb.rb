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

require 'factbase/pre'
require 'factbase/rules'

def fb_rules(fb)
  rules = Dir.glob(File.join('rules', '*.fe')).map { |f| File.read(f) }
  Factbase::Rules.new(
    fb,
    "(and \n#{rules.join("\n")}\n)"
  )
end

def fb_pre(fb)
  Factbase::Pre.new(fb) do |f|
    max = $fb.query('(eq _id (max _id))').each.to_a[0]
    f._id = (max.nil? ? 0 : max._id) + 1
    f._time = Time.now
    f._version = "#{Factbase::VERSION}/#{Judges::VERSION}/#{$options.judges_action_version}"
  end
end

def fb
  fb_pre(fb_rules($fb))
end
