-- different idents: ineligible_key = key .. x must not fire lu-string-concat-hot
local INELIGIBLE_SUFFIX = ":no"
for i, id in ipairs({"a", "b"}) do
  local key = "scope|" .. id
  local ineligible_key = key .. INELIGIBLE_SUFFIX
  assert(ineligible_key ~= nil)
end
