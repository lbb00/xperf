def good(paths)
  paths.each do |path|
    File.read(path)
  end
end
