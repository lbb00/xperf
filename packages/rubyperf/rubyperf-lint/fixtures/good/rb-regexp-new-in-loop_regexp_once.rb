def match_all(lines)
  re = Regexp.new('\A\d+\z')
  n = 0
  lines.each do |line|
    n += 1 if re.match?(line)
  end
  n
end
