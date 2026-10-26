def match_all(lines)
  n = 0
  lines.each do |line|
    re = Regexp.new(line)
    n += 1 if re.match?(line)
  end
  n
end
