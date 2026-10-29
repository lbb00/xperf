#!/usr/bin/env lua
-- Evidence for "lu-table-insert-hot": table.insert vs t[i]= / t[#t+1]=
local ROUNDS = tonumber(os.getenv("LU001_ROUNDS") or "9")
local WARM = tonumber(os.getenv("LU001_WARM") or "3")
local N = tonumber(os.getenv("LU001_N") or "200000")
local N_SMALL = tonumber(os.getenv("LU001_N_SMALL") or "100")
local REPS_SMALL = tonumber(os.getenv("LU001_SMALL_REPS") or "2000")

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    return src:sub(2):match("(.+)/[^/]+$") or "."
  end
  return "."
end
local OUT = os.getenv("EVIDENCE_DIR") or (script_dir() .. "/../../evidence")

local function median(xs)
  local a = {}
  for i = 1, #xs do a[i] = xs[i] end
  table.sort(a)
  local n = #a
  if n == 0 then return 0 end
  if n % 2 == 1 then return a[(n + 1) / 2] end
  return 0.5 * (a[n / 2] + a[n / 2 + 1])
end

local function time_many(fn)
  for _ = 1, WARM do fn() end
  local samples = {}
  local sink = 0
  for r = 1, ROUNDS do
    collectgarbage("collect")
    local t0 = os.clock()
    sink = sink + fn()
    samples[r] = (os.clock() - t0) * 1e3
  end
  return median(samples), sink
end

local ver = (io.popen("lua5.4 -v 2>&1"):read("*l") or _VERSION):match("^(Lua [%d%.]+)") or _VERSION
local ts = os.date("!%Y-%m-%dT%H:%M:%SZ")
local lines = {}
local function emit(case, role, med, ops, ratio)
  lines[#lines + 1] = string.format(
    '{"rule":"lu-table-insert-hot","case":"%s","role":"%s","lua":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}',
    case, role, ver, med, ops, ratio, ts)
  io.stderr:write(string.format("  %s %s median=%.3f ms ops=%d ratio=%.3f\n", role, case, med, ops, ratio))
end

io.stderr:write(string.format("lu-table-insert-hot insert-vs-index n=%d\n", N))
local med_a = time_many(function()
  local t = {}
  for i = 1, N do t[i] = i end
  return #t
end)
local med_b = time_many(function()
  local t = {}
  for i = 1, N do table.insert(t, i) end
  return #t
end)
emit("index_assign", "after", med_a, N, 1)
emit("table_insert", "before", med_b, N, med_b / math.max(med_a, 1e-9))

-- also #t+1 append style
local med_a2 = time_many(function()
  local t = {}
  for i = 1, N do t[#t + 1] = i end
  return #t
end)
emit("hash_len_append", "after", med_a2, N, 1)
emit("table_insert_vs_len", "before", med_b, N, med_b / math.max(med_a2, 1e-9))

local med_sa = time_many(function()
  local sink = 0
  for _ = 1, REPS_SMALL do
    local t = {}
    for i = 1, N_SMALL do t[i] = i end
    sink = sink + #t
  end
  return sink
end)
local med_sb = time_many(function()
  local sink = 0
  for _ = 1, REPS_SMALL do
    local t = {}
    for i = 1, N_SMALL do table.insert(t, i) end
    sink = sink + #t
  end
  return sink
end)
emit("small_index", "after", med_sa, N_SMALL, 1)
emit("small_insert", "before", med_sb, N_SMALL, med_sb / math.max(med_sa, 1e-9))

local path = OUT:gsub("/+$", "") .. "/lu-table-insert-hot.jsonl"
local f = assert(io.open(path, "w"))
for _, line in ipairs(lines) do f:write(line .. "\n") end
f:close()
io.stderr:write("wrote " .. path .. "\n")
for _, line in ipairs(lines) do print(line) end
