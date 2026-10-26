local function grow(n)
  local t = {}
  for i = 1, n do
    t[i] = i
  end
  return t
end
print(#grow(8))
