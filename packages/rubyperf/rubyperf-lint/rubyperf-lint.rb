#!/usr/bin/env ruby
# frozen_string_literal: true

MSG = {
  "rb-string-plus-in-loop" => "string += in loop; prefer <<",
  "rb-array-plus-rebind" => "Array + / concat rebinding in loop; prefer <<",
  "rb-puts-in-loop" => "puts/print in loop; gate or buffer",
  "rb-regexp-new-in-loop" => "Regexp.new in a loop; compile outside only when this pattern stays the same",
  "rb-json-in-loop" => "JSON.parse/generate in a loop; hoist only when this text stays the same",
  "rb-file-read-in-loop" => "file read in a loop; read once when the path stays the same",
}.freeze
RE_REGEXP_NEW = /Regexp\.new\b|Regexp\.compile\b/
RE_JSON = /JSON\.(?:parse|generate|dump|pretty_generate|load)\b/
RE_FILE_READ = /\bFile\.(?:read|open|readlines)\b/
RE_REGEXP_ARG = /(?:Regexp\.new|Regexp\.compile)\s*\(?\s*([^)\n,]*)/
RE_JSON_ARG = /JSON\.(?:parse|generate|dump|pretty_generate|load)\s*\(?\s*([^)\n,]*)/
RE_FILE_ARG = /\bFile\.(?:read|open|readlines)\s*\(?\s*([^)\n,]*)/
ALWAYS_SKIP = %w[.git vendor node_modules .bundle].freeze
# reverse-opt: test/spec drown signal on Rails/Sidekiq/Jekyll
NOISE_SKIP = %w[spec test tests features tmp].freeze

Finding = Struct.new(:rule, :path, :line, :message)

$enable_reverse_opt = true

def usage(code)
  warn <<~USAGE
    Usage: rubyperf-lint.rb PATH... [options]
      --format text|json
      --severity RULE=error|hint|off
      --strict-hints
      --no-fail
      --raw-paths          include test/spec (baseline dumps)
  USAGE
  exit code
end

def apply_sev!(sev, spec)
  rule, level = spec.split("=", 2)
  usage(2) unless rule && level && sev.key?(rule) && %w[off hint error].include?(level)
  sev[rule] = level
end

def strip_comment(line)
  in_str = nil
  i = 0
  while i < line.length
    c = line[i]
    if in_str
      if c == "\\" && i + 1 < line.length
        i += 2
        next
      end
      in_str = nil if c == in_str
      i += 1
      next
    end
    if c == '"' || c == "'"
      in_str = c
      i += 1
      next
    end
    return line[0...i] if c == "#"
    i += 1
  end
  line
end

def looks_string_plus?(code)
  # reverse-opt: require string evidence; default false kills Array += / numeric counters
  return false if code =~ /\+=\s*\d/
  return true if code =~ /\+=\s*["']/
  return true if code =~ /\+=\s*.*\.to_s\b/ || code =~ /\+=\s*.*inspect\b/
  if code =~ /(\w+)\s*\+=\s*/
    lhs = Regexp.last_match(1)
    numish = /\A(i|j|k|n|m|x|y|idx|index|count|cnt|len|length|size|offset|start|pos|total|sum|num|bytes?)\z/i
    numish_sfx = /(count|offset|total|sum|index|len|size|pos|num|bytes?)\z/i
    return false if lhs.match?(numish) || lhs.match?(numish_sfx)
    stringy_lhs = /\A(s|str|string|msg|message|text|out|buf|buffer|name|path|line|html|body)\z/i
    return true if lhs.match?(stringy_lhs)
    if code =~ /\+=\s*([\w.@]+)/
      rhs = Regexp.last_match(1)
      return false if rhs.match?(numish) || rhs.match?(numish_sfx)
    end
  end
  false
end

def dumper_path?(path)
  base = File.basename(path)
  return true if base.include?("schema_dumper") || base.include?("explain_pretty")
  return true if base.include?("dumper")
  false
end


def for_names(code)
  names = []
  if code =~ /\bfor\s+(.+?)\s+in\b/
    names.concat(Regexp.last_match(1).scan(/[A-Za-z_]\w*/))
  end
  if code =~ /\|([^|]*)\|/
    names.concat(Regexp.last_match(1).scan(/[A-Za-z_]\w*/))
  end
  names.reject { |n| n == "_" }
end

def arg_uses?(code, re, names)
  return false if names.empty?
  m = re.match(code)
  return false unless m
  arg = m[1].to_s.gsub(/"[^"]*"|'[^']*'/, " ")
  names.any? { |n| arg.match?(/\b#{Regexp.escape(n)}\b/) }
end

def scan_file(path)
  out = []
  depth = 0
  in_loop = 0
  loop_names = []
  File.foreach(path).with_index(1) do |raw, line_no|
    code = strip_comment(raw)
    do_count = code.scan(/\bdo\b/).length
    end_count = code.scan(/\bend\b/).length
    opens_brace = code.count("{")
    closes_brace = code.count("}")
    # each/map/filter_map/… open a block body we treat as a loop for heuristics
    loop_here = !!(code =~ /\b(times|loop|while|until|for)\b/ ||
                   code =~ /\.(each|map|flat_map|filter_map|collect)\b/)
    if loop_here
      in_loop = depth + 1
      loop_names.concat(for_names(code))
    end
    if in_loop.positive? && depth >= in_loop
      if code =~ /\w+\s*\+=\s*/
        skip_rb1 = $enable_reverse_opt && path.include?("/tui/")
        if !skip_rb1 && (!$enable_reverse_opt || looks_string_plus?(code))
          out << Finding.new("rb-string-plus-in-loop", path, line_no, MSG["rb-string-plus-in-loop"])
        end
      end
      # reverse-opt: bare Array#concat mutates in place (good); only flag rebinding
      if code =~ /(\w+)\s*=\s*\1\s*\+/ || code =~ /(\w+)\s*=\s*\1\.concat\s*\(/
        out << Finding.new("rb-array-plus-rebind", path, line_no, MSG["rb-array-plus-rebind"])
      elsif !$enable_reverse_opt && code =~ /\.concat\s*\(/
        out << Finding.new("rb-array-plus-rebind", path, line_no, MSG["rb-array-plus-rebind"])
      end
      # Note: do not match bare `p` (common block param); only puts/print/pp
      if code =~ /\b(puts|print|pp)\b/
        skip = false
        if $enable_reverse_opt
          skip = true if dumper_path?(path)
          skip = true if code =~ /\b(stream|io|@io|output)\.(puts|print)\b/
          skip = true if code =~ /\$(stderr|stdout)\.(puts|print)\b/
          skip = true if code =~ /\b(STDERR|STDOUT)\.(puts|print)\b/
          # CLI / TUI / rake-task status tables are intentional IO
          base = File.basename(path)
          skip = true if base == "cli.rb" || base == "monitor.rb" || path.include?("/tui/")
          skip = true if path.include?("/tasks/") && code =~ /\bputs\b/
        end
        out << Finding.new("rb-puts-in-loop", path, line_no, MSG["rb-puts-in-loop"]) unless skip
      end
      if RE_REGEXP_NEW.match?(code) && !arg_uses?(code, RE_REGEXP_ARG, loop_names)
        out << Finding.new("rb-regexp-new-in-loop", path, line_no, MSG["rb-regexp-new-in-loop"])
      end
      if RE_JSON.match?(code) && !arg_uses?(code, RE_JSON_ARG, loop_names)
        out << Finding.new("rb-json-in-loop", path, line_no, MSG["rb-json-in-loop"])
      end
      if RE_FILE_READ.match?(code) && !arg_uses?(code, RE_FILE_ARG, loop_names)
        out << Finding.new("rb-file-read-in-loop", path, line_no, MSG["rb-file-read-in-loop"])
      end
    end
    depth += opens_brace + do_count - closes_brace - end_count
    depth = 0 if depth.negative?
    if in_loop.positive? && depth < in_loop
      in_loop = 0
      loop_names = []
    end
  end
  out
rescue Errno::ENOENT
  []
end

def skip_path?(path, root)
  rel = path.sub(/\A#{Regexp.escape(File.expand_path(root))}\/?/, "")
  parts = rel.split(File::SEPARATOR)
  dirs = parts[0...-1]
  return true if dirs.any? { |p| ALWAYS_SKIP.include?(p) }
  # Skip nested fixtures/ unless the user pointed at fixtures directly
  return true if dirs.any? { |p| p == "fixtures" } && !File.expand_path(root).split(File::SEPARATOR).include?("fixtures")
  if $enable_reverse_opt
    return true if dirs.any? { |p| NOISE_SKIP.include?(p) }
  end
  false
end

def scan_path(root)
  root = File.expand_path(root)
  if File.file?(root)
    return root.end_with?(".rb") ? scan_file(root) : []
  end
  all = []
  Dir.glob(File.join(root, "**", "*.rb")).each do |f|
    next if skip_path?(f, root)
    scan_file(f).each { |finding| all << finding }
  end
  all
end

sev = { "rb-string-plus-in-loop" => "off", "rb-array-plus-rebind" => "off", "rb-puts-in-loop" => "off", "rb-regexp-new-in-loop" => "hint", "rb-json-in-loop" => "hint", "rb-file-read-in-loop" => "hint" }
format = "text"
strict_hints = false
no_fail = false
paths = []
argv = ARGV.dup
usage(2) if argv.empty?
i = 0
while i < argv.length
  a = argv[i]
  case a
  when "-h", "--help" then usage(0)
  when "--format"
    i += 1
    usage(2) if i >= argv.length
    format = argv[i]
  when /\A--format=/
    format = a.split("=", 2)[1]
  when "--severity"
    i += 1
    usage(2) if i >= argv.length
    apply_sev!(sev, argv[i])
  when /\A--severity=/
    apply_sev!(sev, a.split("=", 2)[1])
  when "--strict-hints" then strict_hints = true
  when "--no-fail" then no_fail = true
  when "--raw-paths" then $enable_reverse_opt = false
  else
    usage(2) if a.start_with?("-")
    paths << a
  end
  i += 1
end
usage(2) if paths.empty?

findings = []
paths.each do |p|
  scan_path(p).each { |f| findings << f }
end
nerr = 0
nhint = 0
rows = []
lines = []
findings.each do |f|
  level = sev[f.rule] || "hint"
  next if level == "off"
  if level == "error"
    nerr += 1
  else
    nhint += 1
  end
  if format == "json"
    rows << { rule: f.rule, severity: level, path: f.path, line: f.line, message: f.message }
  else
    lines << "#{f.path}:#{f.line}: #{level} #{f.rule}: #{f.message}"
  end
end

if format == "json"
  require "json"
  puts JSON.generate(rows)
else
  puts lines.join("\n") unless lines.empty?
  shown = nerr + nhint
  if shown.positive?
    warn "#{shown} finding(s) (#{nerr} error, #{nhint} hint)"
  else
    warn "ok"
  end
end

exit 0 if no_fail
exit(nerr.positive? || (strict_hints && nhint.positive?) ? 1 : 0)
