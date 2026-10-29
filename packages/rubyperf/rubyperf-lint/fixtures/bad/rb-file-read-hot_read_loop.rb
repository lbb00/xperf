def bad(path, n)
  n.times do
    File.read(path)
  end
end
