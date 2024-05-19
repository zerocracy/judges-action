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

require 'factbase/inv'
require 'factbase/pre'
require 'factbase/rules'

def fb
  fb = Factbase::Rules.new(
    $fb,
    Dir.glob(File.join('rules', '*.fe')).map { |f| File.read(f) }.join("\n")
  )
  fb = Factbase::Inv.new(fb) do |p, v|
    raise '"time" must be of type Time' if p == 'time' && !v.is_a?(Time)
    %w[id issue repository who award].each do |i|
      raise %("#{i}" must be of type Integer) if p == i && !v.is_a?(Integer)
    end
    raise '"what" must match a pattern' if p == 'what' && !v.match?(/^[a-z]+(-[a-z]+)*$/)
  end
  Factbase::Pre.new(fb) do |f|
    f.id = $fb.size
    f.time = Time.now
  end
end
