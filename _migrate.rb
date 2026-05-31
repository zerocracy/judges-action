# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'

DRY_RUN = ARGV.include?('--dry-run')
BASE = 'https://api.github.com'
VCR_DIR = 'test/vcr_cassettes'
TEST_DIR = 'test/judges'
SKIP_FILES = %w[
  test-who-has-name.rb
  test-issue-was-closed.rb
  test-who-is-alive.rb
  test-type-was-attached.rb
  test-issue-was-opened.rb
].to_set

DONE = SKIP_FILES.to_set

$warnings = []

def warn(s)
  $warnings << s
  warn("  ⚠ #{s}")
end

def ruby_to_json(val)
  case val
  when String then val
  when Integer, Float then val
  when TrueClass, FalseClass then val
  when NilClass then nil
  when Array then val.map { |v| ruby_to_json(v) }
  else
    if val.is_a?(Hash)
      val.transform_keys { |k| k.to_s }.transform_values { |v| ruby_to_json(v) }
    else
      warn("Unhandled type: #{val.class} (#{val.inspect})")
      val.to_s
    end
  end
end

class RubyLiteralParser
  def initialize(src)
    @src = src.strip
    @pos = 0
  end

  def parse
    skip_space
    return nil if @pos >= @src.size
    case @src[@pos]
    when "'" then parse_single_quoted_string
    when '"' then parse_double_quoted_string
    when 't' then parse_true
    when 'f' then parse_false
    when 'n' then parse_nil
    when '[' then parse_array
    when '{' then parse_hash
    when '(' then parse_parens
    when /\d/ then parse_number
    when ':' then parse_symbol_literal
    else
      if @src[@pos..].start_with?('Time.parse(')
        parse_time_parse
      else
        bare = parse_bareword
        if bare
          bare.to_sym.inspect
        else
          warn("Cannot parse at pos #{@pos}: #{@src[@pos..@src.index(/\s|,|\]|\}|\)/)]}")
          nil
        end
      end
    end
  end

  private

  def skip_space
    @pos += 1 while @pos < @src.size && @src[@pos] =~ /\s/
  end

  def parse_single_quoted_string
    @pos += 1
    start = @pos
    @pos += 1 while @pos < @src.size && @src[@pos] != "'"
    val = @src[start...@pos]
    @pos += 1 if @pos < @src.size
    val
  end

  def parse_double_quoted_string
    @pos += 1
    start = @pos
    @pos += 1 while @pos < @src.size && @src[@pos] != '"'
    val = @src[start...@pos]
    @pos += 1 if @pos < @src.size
    val
  end

  def parse_true
    return unless @src[@pos..].start_with?('true')
    @pos += 4
    true
  end

  def parse_false
    return unless @src[@pos..].start_with?('false')
    @pos += 5
    false
  end

  def parse_nil
    return unless @src[@pos..].start_with?('nil')
    @pos += 3
    nil
  end

  def parse_number
    start = @pos
    @pos += 1 while @pos < @src.size && @src[@pos] =~ /\d/
    @src[start...@pos].to_i
  end

  def parse_symbol_literal
    @pos += 1
    name = parse_bareword
    name ? name.to_sym : nil
  end

  def parse_bareword
    start = @pos
    @pos += 1 while @pos < @src.size && @src[@pos] =~ /\w/
    return nil if @pos == start
    @src[start...@pos]
  end

  def parse_array
    @pos += 1
    result = []
    loop do
      skip_space
      break if @pos >= @src.size || @src[@pos] == ']'
      elem = parse
      result << elem if elem != :comma
      skip_space
      if @pos < @src.size && @src[@pos] == ','
        @pos += 1
      end
      skip_space
    end
    @pos += 1 if @pos < @src.size && @src[@pos] == ']'
    result
  end

  def parse_hash
    @pos += 1
    result = {}
    loop do
      skip_space
      break if @pos >= @src.size || @src[@pos] == '}'
      key = parse_hash_key
      skip_space
      if @pos < @src.size && @src[@pos] == '='
        @pos += 1
        @pos += 1 if @pos < @src.size && @src[@pos] == '>'
      end
      skip_space
      val = parse
      result[key.to_s] = val if key && val != :comma
      skip_space
      if @pos < @src.size && @src[@pos] == ','
        @pos += 1
      end
      skip_space
    end
    @pos += 1 if @pos < @src.size && @src[@pos] == '}'
    result
  end

  def parse_hash_key
    skip_space
    case @src[@pos]
    when "'" then parse_single_quoted_string
    when '"' then parse_double_quoted_string
    when ':' then parse_symbol_literal
    else
      bare = parse_bareword
      skip_space
      if @pos < @src.size
        if @src[@pos] == '='
          bare
        elsif @src[@pos] == ':'
          @pos += 1
          bare
        else
          bare
        end
      else
        bare
      end
    end
  end

  def parse_parens
    @pos += 1
    val = parse
    skip_space
    @pos += 1 if @pos < @src.size && @src[@pos] == ')'
    val
  end

  def parse_time_parse
    @pos += 'Time.parse('.size
    arg = parse
    skip_space
    @pos += 1 if @pos < @src.size && @src[@pos] == ')'
    arg
  end
end

def body_to_json(src)
  return '""' if src.strip.empty?
  parser = RubyLiteralParser.new(src)
  val = parser.parse
  if val.nil?
    warn("Failed to parse body: #{src[0..80]}")
    return '{}'
  end
  converted = ruby_to_json(val)
  JSON.generate(converted)
rescue StandardError => e
  warn("Error converting body to JSON: #{e.message} (#{src[0..80]})")
  '{}'
end

def normalize_url(url)
  u = url.sub(BASE, '')
  u.gsub(/['"]/, '')
end

def cassette_name(test_name)
  test_name.sub(/^test_/, '').tr('_', '-')
end

def generate_cassette(dir, name, interactions)
  return if DRY_RUN
  FileUtils.mkdir_p(dir)
  data = { 'http_interactions' => interactions }
  File.write(File.join(dir, "#{name}.yml"), data.to_yaml)
  puts("      #{name}.yml (#{interactions.size} interactions)")
end

def interaction(method, uri, status, body_json, headers)
  {
    'request' => {
      'method' => method.to_s,
      'uri' => uri,
      'body' => { 'encoding' => 'UTF-8', 'string' => '' },
      'headers' => {}
    },
    'response' => {
      'status' => { 'code' => status, 'message' => '' },
      'headers' => headers.transform_values { |v| [v] },
      'body' => { 'encoding' => 'UTF-8', 'string' => body_json },
      'http_version' => '1.1'
    },
    'recorded_at' => 'Mon, 01 Jan 2024 00:00:00 GMT'
  }
end

REPO_JSON = '{"id":42,"full_name":"foo/foo"}'
BASE_HEADERS = { 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '999' }

def prefix_interactions
  [
    interaction(:get, "#{BASE}/repos/foo/foo", 200, REPO_JSON, BASE_HEADERS),
    interaction(:get, "#{BASE}/repositories/42", 200, REPO_JSON, BASE_HEADERS)
  ]
end

def process_file(file_path)
  content = File.read(file_path)
  lines = content.lines
  basename = File.basename(file_path)
  judge_name = basename.sub(/^test-/, '').sub(/\.rb$/, '')
  dir = File.join(VCR_DIR, judge_name)
  puts("\n#{basename}:")
  modified = false
  i = 0
  test_methods = []
  while i < lines.size
    line = lines[i]
    if line =~ /^\s+def test_(\w+)/
      test_name = Regexp.last_match(1)
      test_start = i
      indent = line[/^\s+/].to_s
      depth = 0
      j = i
      while j < lines.size
        l = lines[j]
        if /^\s+def\b/.match?(l)
          depth += 1
        elsif /^#{indent}end\b/.match?(l)
          depth -= 1
          if depth <= 0
            test_end = j
            break
          end
        end
        j += 1
      end
      test_methods << { name: test_name, start: test_start, end: test_end || j }
      i = test_end ? test_end + 1 : j + 1
    else
      i += 1
    end
  end
  processed = 0
  test_methods.each do |tm|
    next unless needs_migration?(content.lines[tm[:start]..tm[:end]].join)
    modified = true
    processed += 1
    process_test(content.lines[tm[:start]..tm[:end]], tm, dir, judge_name, basename, content.lines[tm[:start]])
  end
  if processed > 0
    puts("    #{processed} tests migrated")
  else
    puts('    no stub_github tests found')
  end
  modified
end

def needs_migration?(body)
  body.include?('WebMock') || body.include?('stub_github')
end

def already_migrated?(body)
  body.include?('VCR.use_cassette')
end

def process_test(test_lines, tm, dir, _judge_name, _basename, first_line)
  test_name = tm[:name]
  cname = cassette_name(test_name)
  raw = test_lines.join
  all_stubs = extract_stubs(raw)
  return if all_stubs.empty?
  prefix = all_stubs.any? { |s| s[:url].include?('/repos/foo/foo') || s[:url].include?('/repositories/42') }
  ints = prefix ? prefix_interactions : []
  all_stubs.each do |stub|
    body_json = body_to_json(stub[:body_src])
    ints << interaction(stub[:method], stub[:url], stub[:status], body_json, BASE_HEADERS)
  end
  unless ints.empty?
    generate_cassette(dir, cname, ints)
  end
  rewrite_test(test_lines, cname, dir, first_line)
end

def extract_stubs(source)
  stubs = []
  idx = 0
  while idx < source.size
    pos = source.index('stub_github', idx)
    break unless pos
    paren_start = source.index('(', pos)
    break unless paren_start
    depth = 0
    in_single_quote = false
    in_double_quote = false
    end_pos = nil
    (paren_start + 1...source.size).each do |i|
      ch = source[i]
      prev = i > 0 ? source[i - 1] : ''
      if !in_double_quote && ch == "'" && prev != '\\'
        in_single_quote = !in_single_quote
      elsif !in_single_quote && ch == '"' && prev != '\\'
        in_double_quote = !in_double_quote
      end
      unless in_single_quote || in_double_quote
        case ch
        when '(' then depth += 1
        when ')' then depth -= 1
        when '{' then depth += 1
        when '}' then depth -= 1
        when '[' then depth += 1
        when ']' then depth -= 1
        end
      end
      if depth < 0
        end_pos = i
        break
      end
    end
    break unless end_pos
    call_src = source[(paren_start + 1)...end_pos]
    stubs << parse_stub_call(call_src)
    idx = end_pos + 1
  end
  stubs
end

def parse_stub_call(src)
  result = { url: '', status: 200, method: :get, body_src: '' }
  url_match = src.match(/['"]([^'"]+)['"]/)
  result[:url] = url_match[1] if url_match
  if src =~ /method:\s*:(\w+)/
    result[:method] = Regexp.last_match(1).to_sym
  end
  if src =~ /status:\s*(\d+)/
    result[:status] = Regexp.last_match(1).to_i
  end
  body_match = src.match(/body:\s*/)
  if body_match
    body_start = body_match.end(0)
    body_src = extract_body_value(src, body_start)
    result[:body_src] = body_src
  end
  result
end

def extract_body_value(src, start_pos)
  ch = src[start_pos]
  return '' unless ch
  depth = 0
  in_single_quote = false
  in_double_quote = false
  end_pos = nil
  case src[start_pos]
  when '{', '['
    depth = 1
    (start_pos + 1...src.size).each do |i|
      c = src[i]
      prev = i > 0 ? src[i - 1] : ''
      if !in_double_quote && c == "'" && prev != '\\'
        in_single_quote = !in_single_quote
      elsif !in_single_quote && c == '"' && prev != '\\'
        in_double_quote = !in_double_quote
      end
      unless in_single_quote || in_double_quote
        case c
        when '{', '[', '(' then depth += 1
        when '}', ']', ')' then depth -= 1
        end
      end
      if depth == 0
        end_pos = i
        break
      end
    end
    src[start_pos..end_pos]
  when "'"
    start_pos.upto(src.size - 1) do |i|
      if src[i] == "'" && (i == start_pos || src[i - 1] != '\\')
        return src[start_pos..i]
      end
    end
    src[start_pos..-1]
  when '"'
    start_pos.upto(src.size - 1) do |i|
      if src[i] == '"' && (i == start_pos || src[i - 1] != '\\')
        return src[start_pos..i]
      end
    end
    src[start_pos..-1]
  when 't', 'f', 'n'
    if src[start_pos..].start_with?('true')
      return 'true'
    elsif src[start_pos..].start_with?('false')
      return 'false'
    elsif src[start_pos..].start_with?('nil')
      return 'nil'
    end
  when /\d/
    m = src[start_pos..].match(/\A\d+/)
    return m[0] if m
  end
  ''
end

def rewrite_test(test_lines, cname, dir, _first_line)
  basename = File.basename(dir)
  result = []
  in_single_quote = false
  in_double_quote = false
  skip_lines = Set.new
  test_lines.each_with_index do |line, idx|
    next unless line.include?('stub_github') || line.include?('stub_request')
    j = idx
    d = 0
    begin
      l = test_lines[j]
      l.each_char.with_index do |ch, ci|
        prev = ci > 0 ? l[ci - 1] : ''
        if !in_double_quote && ch == "'" && prev != '\\'
          in_single_quote = !in_single_quote
        elsif !in_single_quote && ch == '"' && prev != '\\'
          in_double_quote = !in_double_quote
        end
        unless in_single_quote || in_double_quote
          case ch
          when '(', '{', '[' then d += 1
          when ')', '}', ']' then d -= 1
          end
        end
      end
      skip_lines << j
      j += 1
    end while d > 0 && j < test_lines.size
  end
  test_lines.each_with_index do |line, idx|
    if skip_lines.include?(idx)
    elsif line.strip == 'WebMock.disable_net_connect!'
    elsif /^\s+load_it\(/.match?(line)
      indent = line[/^\s+/]
      result << "#{indent}VCR.use_cassette('#{basename}/#{cname}') do\n"
      result << line
    else
      result << line
    end
  end
  result
end

def rewrite_test_simple(test_lines, cname, dir, _first_line)
  basename = File.basename(dir)
  full_source = test_lines.join
  full_source = full_source.gsub(/^(\s*)WebMock\.disable_net_connect!\s*\n/, '')
  result = ''
  i = 0
  while i < full_source.size
    if full_source[i..].start_with?('stub_github(', 'stub_request(')
      paren_pos = full_source.index('(', i)
      next unless paren_pos
      d = 1
      j = paren_pos + 1
      sq = false
      dq = false
      while j < full_source.size && d > 0
        c = full_source[j]
        p = j > 0 ? full_source[j - 1] : ''
        if !dq && c == "'" && p != '\\'
          sq = !sq
        elsif !sq && c == '"' && p != '\\'
          dq = !dq
        end
        unless sq || dq
          case c
          when '(', '{', '[' then d += 1
          when ')', '}', ']' then d -= 1
          end
        end
        j += 1
      end
      i = j
      next
    end
    if full_source[i..].start_with?('load_it(')
      paren_pos = full_source.index('(', i)
      next unless paren_pos
      d = 1
      j = paren_pos + 1
      sq = false
      dq = false
      while j < full_source.size && d > 0
        c = full_source[j]
        p = j > 0 ? full_source[j - 1] : ''
        if !dq && c == "'" && p != '\\'
          sq = !sq
        elsif !sq && c == '"' && p != '\\'
          dq = !dq
        end
        unless sq || dq
          case c
          when '(', '{', '[' then d += 1
          when ')', '}', ']' then d -= 1
          end
        end
        j += 1
      end
      load_it_call = full_source[paren_pos - 'load_it'.size..j - 1]
      indent = load_it_call[/^\s*/] || ''
      result << "#{indent}VCR.use_cassette('#{basename}/#{cname}') do\n"
      result << "#{indent}  #{load_it_call.strip}\n"
      result << "#{indent}end\n"
      i = j
    else
      result << full_source[i]
      i += 1
    end
  end
  result
end

puts "DRY RUN: #{DRY_RUN ? 'YES (no files will be modified)' : 'NO'}"
puts '=' * 60

files = Dir.children(TEST_DIR).select { |f| f.end_with?('.rb') && !DONE.include?(f) }
puts "Found #{files.size} files to process (skipping #{DONE.size} already done)"

files.each do |f|
  file_path = File.join(TEST_DIR, f)
  process_file(file_path)
end

puts "\n" + ('=' * 60)
if $warnings.empty?
  puts 'Done. No warnings.'
else
  puts "Done. #{$warnings.size} warnings (see above)."
end

puts "\nNext steps:"
puts '1. Run the rewritten tests to verify'
puts '2. If tests fail, check cassette content and test rewriting'
