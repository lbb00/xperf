-- variable named to_print must not fire lu-print-hot
local function dump(conf)
  for k, v in pairs(conf) do
    local to_print = v
    if to_print == nil then
      to_print = ""
    end
    -- no print( call
    local _ = to_print
  end
end
return dump
