def load_all(rows)
  out = []
  rows.each do |row|
    out << JSON.parse(row)
  end
  out
end
