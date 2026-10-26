-- names containing "print" must not fire lu-print-in-loop
local function buffered_print(s)
  io.write(s)
end
local function ngx_print(t)
  return t
end
for i = 1, 3 do
  buffered_print(tostring(i))
  ngx_print({ i })
end
