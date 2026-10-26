def parse_all(rows)
  out = []
  rows.each do |row|
    out << Date.parse(row)
    out << Time.parse(row)
    out << DateTime.parse(row)
  end
  out
end
