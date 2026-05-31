# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'yaml'
require 'json'
require 'fileutils'
require 'time'

BASE = 'https://api.github.com'
VCR_DIR = 'test/vcr_cassettes'
TEST_DIR = 'test/judges'
BASE_HEADERS = { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }

REPO_JSON = '{"id":42,"full_name":"foo/foo"}'

DONE = %w[who-has-name issue-was-closed who-is-alive type-was-attached issue-was-opened].to_set

$errors = []

def interaction(method, uri, status, body_json)
  {
    'request' => {
      'method' => method.to_s, 'uri' => uri,
      'body' => { 'encoding' => 'UTF-8', 'string' => '' },
      'headers' => {}
    },
    'response' => {
      'status' => { 'code' => status, 'message' => '' },
      'headers' => BASE_HEADERS.transform_values { |v| [v] },
      'body' => { 'encoding' => 'UTF-8', 'string' => body_json },
      'http_version' => '1.1'
    },
    'recorded_at' => 'Mon, 01 Jan 2024 00:00:00 GMT'
  }
end

def prefix_interactions
  [
    interaction(:get, "#{BASE}/repos/foo/foo", 200, REPO_JSON),
    interaction(:get, "#{BASE}/repositories/42", 200, REPO_JSON)
  ]
end

def body_to_json(src)
  src = src.strip
  return '[]' if src == '[]'
  return '{}' if src == '{}'
  return '""' if src.empty?
  begin
    val = eval(src, TOPLEVEL_BINDING)
    JSON.generate(val)
  rescue Exception => e
    $errors << "eval: #{e.message}"
    src
  end
end

def extract_body_src(src, start)
  ch = src[start]
  return '' unless ch
  sq = false
  dq = false
  depth = 0
  case ch
  when '{', '['
    depth = 1
    (start + 1...src.size).each do |i|
      c = src[i]
      p = i > 0 ? src[i - 1] : ''
      if !dq && c == "'" && p != '\\'
        sq = !sq
      elsif !sq && c == '"' && p != '\\'
        dq = !dq
      end
      unless sq || dq
        case c
        when '{', '[' then depth += 1
        when '}', ']' then depth -= 1
        end
      end
      return src[start..i] if depth == 0
    end
    src[start..-1]
  when "'"
    (start + 1...src.size).each do |i|
      if src[i] == "'" && src[i - 1] != '\\'
        return src[start..i]
      end
    end
    src[start..-1]
  else
    src[start..-1]
  end
end

BASE_GH = 'https://api.github.com'
REPO_BODY = '{"id":42,"full_name":"foo/foo"}'

def parse_stub_event(event_src)
  event_json = body_to_json(event_src)
  event_body = event_json.start_with?('[') ? event_json : "[#{event_json}]"
  [
    { url: "#{BASE_GH}/repos/foo/foo", status: 200, method: 'get', body: REPO_BODY },
    { url: "#{BASE_GH}/repositories/42", status: 200, method: 'get', body: REPO_BODY },
    { url: "#{BASE_GH}/repositories/42/events?per_page=100", status: 200, method: 'get', body: event_body }
  ]
end

def extract_calls(source)
  calls = []
  idx = 0
  while idx < source.size
    m = source.match(/\b(stub_github|stub_request|stub_event)\s*\(/, idx)
    break unless m
    fn = m[1]
    paren = m.end(0) - 1
    depth = 1
    i = paren + 1
    sq = false
    dq = false
    while i < source.size && depth > 0
      c = source[i]
      p = i > 0 ? source[i - 1] : ''
      if !dq && c == "'" && p != '\\'
        sq = !sq
      elsif !sq && c == '"' && p != '\\'
        dq = !dq
      end
      unless sq || dq
        case c
        when '(' then depth += 1
        when ')' then depth -= 1
        end
      end
      i += 1
    end
    call_src = source[(paren + 1)...(i - 1)]
    if fn == 'stub_request' && source[i..] =~ /\.to_return\(/
      to_ret = Regexp.last_match
      td = 1
      j = i + to_ret.begin(0) + '.to_return('.size
      while j < source.size && td > 0
        case source[j]
        when '(' then td += 1
        when ')' then td -= 1
        end
        j += 1
      end
      call_src = source[(paren + 1)...(j - 1)]
      idx = j
    elsif fn == 'stub_event'
      calls.concat(parse_stub_event(call_src))
      idx = i
    else
      idx = i
    end
    if (fn != 'stub_event') && !call_src.strip.empty?
      calls << parse_call(call_src)
    end
  end
  calls
end

def parse_call(src)
  url = ''
  status = 200
  method = 'get'
  body = ''
  if src =~ /['"]([^'"]+)['"]/
    url = Regexp.last_match(1)
  end
  if src =~ /method:\s*:(\w+)/
    method = Regexp.last_match(1)
  end
  if src =~ /status:\s*(\d+)/
    status = Regexp.last_match(1).to_i
  end
  if src =~ /body:\s*/
    bstart = $~.end(0)
    body_src = extract_value(src, bstart)
    body = body_to_json(body_src)
  end
  { url: url, status: status, method: method, body: body }
end

def extract_value(src, start)
  start += 1 while start < src.size && src[start] =~ /\s/
  ch = src[start]
  return '' unless ch
  sq = false
  dq = false
  depth = 0
  case ch
  when '{', '['
    depth = 1
    (start + 1...src.size).each do |i|
      c = src[i]
      p = i > 0 ? src[i - 1] : ''
      if !dq && c == "'" && p != '\\'
        sq = !sq
      elsif !sq && c == '"' && p != '\\'
        dq = !dq
      end
      unless sq || dq
        case c
        when '{', '[' then depth += 1
        when '}', ']' then depth -= 1
        end
      end
      return src[start..i] if depth == 0
    end
    src[start..-1]
  when "'"
    (start + 1...src.size).each do |i|
      if src[i] == "'" && src[i - 1] != '\\'
        return src[(start + 1)...i]
      end
    end
    src[(start + 1)..-1]
  when '"'
    (start + 1...src.size).each do |i|
      if src[i] == '"' && src[i - 1] != '\\'
        return src[(start + 1)...i]
      end
    end
    src[(start + 1)..-1]
  else
    finish = src.index(/[,)]/, start) || src.size
    src[start...finish].strip
  end
end

def test_method_name(line)
  line.match(/def\s+(test_\w+)/)&.captures&.first
end

def find_test_methods(source)
  methods = []
  lines = source.lines
  i = 0
  while i < lines.size
    line = lines[i]
    next(i += 1) unless (name = test_method_name(line))
    indent = line[/^\s+/] || '  '
    depth = 1
    j = i + 1
    while j < lines.size
      l = lines[j]
      if /^#{indent}def\b/.match?(l)
        depth += 1
      elsif /^#{indent}end\b/.match?(l)
        depth -= 1
        if depth == 0
          methods << { name: name, name_line: i, start_line: i + 1, end_line: j - 1 }
          break
        end
      end
      j += 1
    end
    i = j + 1
  end
  methods
end

def cassette_name(test_name)
  test_name.sub(/^test_/, '').tr('_', '-')
end

def has_stubs?(lines)
  lines.any? { |l| l.include?('stub_github') || l.include?('stub_request') }
end

puts 'Generating cassettes from test files...'
puts '=' * 60

files = Dir.children(TEST_DIR).select { |f| f.end_with?('.rb') }.sort

files.each do |file|
  judge = file.sub(/^test-/, '').sub(/\.rb$/, '')
  next if DONE.include?(judge)
  path = File.join(TEST_DIR, file)
  content = File.read(path)
  dir = File.join(VCR_DIR, judge)
  methods = find_test_methods(content)
  stubbed = methods.select { |m| has_stubs?(content.lines[m[:name_line]..m[:end_line]]) }
  next if stubbed.empty?
  puts "\n#{judge}:"
  stubbed.each do |tm|
    body_lines = content.lines[tm[:start_line]..tm[:end_line]]
    next unless body_lines && !body_lines.empty?
    body = body_lines.join
    calls = extract_calls(body)
    next if calls.empty?
    has_prefix = calls.any? { |c| c[:url].include?('/repos/foo/foo') || c[:url].include?('/repositories/42') }
    ints = has_prefix ? prefix_interactions : []
    calls.each { |c| ints << interaction(c[:method], c[:url], c[:status], c[:body]) }
    cname = cassette_name(tm[:name])
    FileUtils.mkdir_p(dir)
    data = { 'http_interactions' => ints }
    File.write(File.join(dir, "#{cname}.yml"), data.to_yaml)
    puts "  #{cname}.yml (#{ints.size} interactions)"
  end
end

puts "\n" + ('=' * 60)
if $errors.empty?
  puts 'Done. No errors.'
else
  puts "Done. #{$errors.size} errors (eval failures)."
  $errors.first(5).each { |e| puts "  #{e}" }
end
