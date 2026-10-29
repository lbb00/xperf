def dump(n)
  buf = []
  n.times { |i| buf << i.to_s }
  puts buf.join("\n")
end
