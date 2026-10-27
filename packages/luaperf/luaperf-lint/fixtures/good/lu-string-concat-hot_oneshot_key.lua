local function keys(t)
  local out = {}
  for k, v in pairs(t) do
    local key = k .. "=" .. tostring(v)
    out[#out + 1] = key
  end
  return out
end
return keys
