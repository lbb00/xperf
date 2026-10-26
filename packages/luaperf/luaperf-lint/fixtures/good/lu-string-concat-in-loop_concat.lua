local function good(n)
  local parts = {}
  for i = 1, n do
    parts[i] = tostring(i)
  end
  return table.concat(parts)
end
