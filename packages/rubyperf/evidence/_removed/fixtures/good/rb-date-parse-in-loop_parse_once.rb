def parse_all(rows)
  anchor = Date.parse("2020-01-01")
  clock = Time.parse("00:00")
  stamp = DateTime.parse("2020-01-01T00:00:00")
  n = 0
  rows.each do |row|
    n += row.length
    _ = Date.strptime(row, "%Y-%m-%d")
    _ = Time.now
    _ = anchor
    _ = clock
    _ = stamp
  end
  n
end
