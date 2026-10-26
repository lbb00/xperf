def good(path, n)
  data = File.read(path)
  n.times do
    data.bytesize
  end
end
