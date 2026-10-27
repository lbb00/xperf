def load_all(blob)
  rows = JSON.parse(blob)
  n = 0
  rows.each do |row|
    n += row.length
  end
  n
end
