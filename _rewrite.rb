# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'fileutils'

TEST_DIR = 'test/judges'
VCR_DIR = 'test/vcr_cassettes'

DONE = %w[who-has-name issue-was-closed who-is-alive type-was-attached issue-was-opened].to_set

HARD = %w[
  add-review-comments
  code-was-reviewed
  dimensions-of-terrain
  eliminate-ghosts
  erase-repository
  find-all-issues
  find-earliest-issue
  find-latest-issue
  find-missing-issues
  github-events
  is-human-or-robot
  pull-was-merged
  quality-of-service
  quantity-of-deliverables
].to_set

$warnings = []

def stub_ranges(source)
  ranges = []
  lines = source.lines
  lines.each_with_index do |line, idx|
    next unless line.include?('stub_github') || line.include?('stub_request')
    depth = 0
    j = idx
    while j < lines.size
      l = lines[j]
      in_sq = false
      in_dq = false
      l.each_char do |c|
        if !in_dq && c == "'"
          in_sq = !in_sq
        elsif !in_sq && c == '"'
          in_dq = !in_dq
        end
        next if in_sq || in_dq
        case c
        when '(', '{', '[' then depth += 1
        when ')', '}', ']' then depth -= 1
        end
      end
      if depth <= 0
        ranges << [idx, j]
        break
      end
      j += 1
    end
  end
  ranges
end

def process_file(path, dry_run: false)
  content = File.read(path)
  basename = File.basename(path)
  judge = basename.sub(/^test-/, '').sub(/\.rb$/, '')
  orig = content.dup
  lines = content.lines
  result = []
  i = 0
  while i < lines.size
    line = lines[i]
    if line =~ /^\s+def\s+(test_\w+)/
      test_name = Regexp.last_match(1)
      cname = test_name.sub(/^test_/, '').tr('_', '-')
      line[/^\s+/]
      has_stubs = stub_ranges(lines[i..-1].join).any?
      if has_stubs
        method_start = i
        method_end = find_method_end(lines, i)
        method_lines = lines[method_start..method_end]
        stubs = stub_ranges(method_lines.join)
        skip = Set.new
        stubs.each { |s| (s[0]..s[1]).each { |ln| skip << (method_start + ln) } }
        method_lines.each_with_index do |ml, mi|
          skip << (method_start + mi) if ml.strip == 'WebMock.disable_net_connect!'
        end
        load_it_start = nil
        load_it_end = nil
        (method_start..method_end).each do |li|
          next unless lines[li].include?('load_it(')
          load_it_start = li
          depth = 0
          sq = dq = false
          prev = ''
          (li..method_end).each do |lj|
            lines[lj].each_char do |c|
              if !dq && c == "'" && prev != '\\'
                sq = !sq
              elsif !sq && c == '"' && prev != '\\'
                dq = !dq
              end
              prev = c
              next if sq || dq
              case c
              when '(' then depth += 1
              when ')' then depth -= 1
              end
            end
            if depth == 0
              load_it_end = lj
              break
            end
          end
          break
        end
        j = method_start
        while j <= method_end
          if j == (load_it_start || method_end)
            if load_it_start
              li_indent = lines[load_it_start][/^\s+/]
              result << "#{li_indent}VCR.use_cassette('#{judge}/#{cname}') do\n"
              (load_it_start..load_it_end).each { |lj| result << "#{li_indent}  #{lines[lj].strip}\n" }
              result << "#{li_indent}end\n"
              j = load_it_end + 1
            else
              result << lines[j]
              j += 1
            end
          elsif skip.include?(j) || lines[j].strip == 'WebMock.disable_net_connect!'
            j += 1
          else
            result << lines[j]
            j += 1
          end
        end
        i = method_end + 1
      else
        result << line
        i += 1
      end
    else
      result << line
      i += 1
    end
  end
  new_content = result.join
  if new_content != orig
    if dry_run
      puts("  #{basename}: would modify (#{(orig.lines.size - new_content.lines.size).abs} lines changed)")
    else
      File.write(path, new_content)
      puts("  #{basename}: modified")
    end
    return true
  end
  false
end

def find_method_end(lines, start)
  indent = lines[start][/^\s+/] || '  '
  depth = 1
  (start + 1...lines.size).each do |i|
    l = lines[i]
    if /^#{indent}def\b/.match?(l)
      depth += 1
    elsif /^#{indent}end\b/.match?(l)
      depth -= 1
      return i if depth == 0
    end
  end
  lines.size - 1
end

dry_run = ARGV.delete('--dry-run')

puts "Rewriting test files (dry_run: #{dry_run})"
puts '=' * 60

files =
  if ARGV.empty?
    Dir.children(TEST_DIR).select { |f| f.end_with?('.rb') }.sort
  else
    ARGV
  end

files.each do |f|
  judge = f.sub(/^test-/, '').sub(/\.rb$/, '')
  next if DONE.include?(judge)
  path = File.join(TEST_DIR, f)
  next unless File.exist?(path)
  cassette_dir = File.join(VCR_DIR, judge)
  has_cassettes = Dir.exist?(cassette_dir) && !Dir.empty?(cassette_dir)
  if !has_cassettes && !dry_run
    puts "  #{f}: SKIP (no cassettes in #{cassette_dir})"
    next
  end
  process_file(path, dry_run: dry_run)
end

puts '=' * 60
puts 'Done.'
