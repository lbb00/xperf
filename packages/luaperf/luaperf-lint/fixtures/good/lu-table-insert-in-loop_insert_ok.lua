-- table.insert collect is idiomatic; lu-table-insert-in-loop default off — file must stay clean under defaults
local function collect(xs)
  local out = {}
  for _, x in ipairs(xs) do
    table.insert(out, x)
  end
  return out
end
return collect
