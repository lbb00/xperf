def join_parts(parts)
  s = +""
  parts.each { |p| s << p }
  s
end

puts join_parts(%w[a b c])
