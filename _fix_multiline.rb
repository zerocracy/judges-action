# frozen_string_literal: true

require 'fileutils'

def process_file(path)
  content = File.read(path)
  orig = content.dup
  basename = File.basename(path)
  judge = basename.sub(/^test-/, '').sub(/\.rb$/, '')
  result = []
  lines = content.lines
  i = 0
  while i < lines.size
    line = lines[i]
    if line =~ /^\s+def\s+(test_\w+)/
      test_name = Regexp.last_match(1)
      cname = test_name.sub(/^test_/, '').tr('_', '-')
      indent = line[/^\s+/] || '  '
      depth = 1
      method_end = nil
      (i + 1...lines.size).each do |j|
        l = lines[j]
        if /^#{indent}def\b/.match?(l)
          depth += 1
        elsif /^#{indent}end\b/.match?(l)
          depth -= 1
          if depth == 0
            method_end = j
            break
          end
        end
      end
      method_lines = lines[i..method_end]
      body_src = method_lines.join
      has_stubs = body_src.include?('stub_github') || body_src.include?('stub_request')
      if has_stubs
        load_it_start = nil
        load_it_end = nil
        method_lines.each_with_index do |ml, mi|
          next unless ml.include?('load_it(')
          load_it_start = i + mi
          src_after = method_lines[mi..-1].join
          d = 0
          sq = false
          dq = false
          src_after.each_char.with_index do |c, ci|
            prev = ci > 0 ? src_after[ci - 1] : ''
            if !dq && c == "'" && prev != '\\'
              sq = !sq
            elsif !sq && c == '"' && prev != '\\'
              dq = !dq
            end
            unless sq || dq
              case c
              when '(' then d += 1
              when ')' then d -= 1
              end
            end
            if d == 0
              offset_into_method = mi + src_after[0..ci].count("\n")
              load_it_end = i + offset_into_method
              break
            end
          end
          break
        end
        skip = {}
        method_lines.each_with_index do |ml, mi|
          gi = i + mi
          next unless ml.include?('stub_github') || ml.include?('stub_request')
          d = 0
          sq = false
          dq = false
          ml.each_char do |c|
            prev = ''
            if !dq && c == "'" && prev != '\\'
              sq = !sq
            elsif !sq && c == '"' && prev != '\\'
              dq = !dq
            end
            next if sq || dq
            case c
            when '(', '{', '[' then d += 1
            when ')', '}', ']' then d -= 1
            end
          end
          skip[gi] = true
          next unless d > 0
          j = 1
          while d > 0 && (gi + j) < lines.size
            l = lines[gi + j]
            l.each_char do |c|
              case c
              when '(', '{', '[' then d += 1
              when ')', '}', ']' then d -= 1
              end
            end
            skip[gi + j] = true if d > 0
            j += 1
          end
        end
        j = i
        while j <= method_end
          if j == load_it_start
            li_indent = lines[load_it_start][/^\s+/]
            result << "#{li_indent}VCR.use_cassette('#{judge}/#{cname}') do\n"
            result << "#{li_indent}  #{lines[load_it_start].strip}\n"
            j = load_it_start + 1
            while j <= load_it_end
              result << "#{li_indent}  #{lines[j].strip}\n"
              j += 1
            end
            result << "#{li_indent}end\n"
          elsif skip[j] || lines[j].strip == 'WebMock.disable_net_connect!'
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
  new = result.join
  if new == orig
    puts("#{basename}: unchanged")
  else
    File.write(path, new)
    puts("#{basename}: modified (#{orig.lines.size - new.lines.size} lines change)")
  end
end

ARGV.each { |f| process_file(f) }
