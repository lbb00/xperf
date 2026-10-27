#!/usr/bin/env lua
-- Evidence microbench for lu-string-concat-hot → packages/luaperf/evidence/lu-string-concat-hot.jsonl
-- Smell: s = s .. chunk in a numeric for; fix: parts then table.concat.
-- Timer: os.clock() CPU seconds (single-threaded; ≈ wall for these kernels).

local ROUNDS = tonumber(os.getenv("LU002_ROUNDS") or "9")
local WARM = tonumber(os.getenv("LU002_WARM") or "3")
local N_DIGITS = tonumber(os.getenv("LU002_N_DIGITS") or "20000")
local N_CHUNK = tonumber(os.getenv("LU002_N_CHUNK") or "10000")
local N_SMALL = tonumber(os.getenv("LU002_N_SMALL") or "100")
local CHUNK = string.rep("x", 32)

local OUT =
  os.getenv("EVIDENCE_DIR")
  or (arg and arg[0] and arg[0]:match("(.+)/[^/]+$") and
      (arg[0]:match("(.+)/[^/]+$") .. "/../../evidence"))
  or "packages/luaperf/evidence"

-- resolve relative to this script
local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    local p = src:sub(2)
    return p:match("(.+)/[^/]+$") or "."
  end
  return "."
end
OUT = os.getenv("EVIDENCE_DIR") or (script_dir() .. "/../../evidence")

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
    local t1 = os.clock()
    samples[r] = (t1 - t0) * 1e3
  end
  if sink ~= sink then error("nan sink") end
  return median(samples), sink
end

-- Pair A: matches fixtures bad/lu002_concat_loop.lua vs good/lu002_concat.lua
local function case_digits_concat()
  local s = ""
  for i = 1, N_DIGITS do
    s = s .. tostring(i)
  end
  return #s
end

local function case_digits_table_concat()
  local parts = {}
  for i = 1, N_DIGITS do
    parts[i] = tostring(i)
  end
  return #table.concat(parts)
end

-- Pair B: fixed-size chunks (classic quadratic accumulation)
local function case_chunk_concat()
  local s = ""
  for _ = 1, N_CHUNK do
    s = s .. CHUNK
  end
  return #s
end

local function case_chunk_table_concat()
  local parts = {}
  for i = 1, N_CHUNK do
    parts[i] = CHUNK
  end
  return #table.concat(parts)
end

-- Pair C: small N (oneshot-ish) — expect ~1×
local function case_small_concat()
  local s = ""
  for i = 1, N_SMALL do
    s = s .. tostring(i)
  end
  return #s
end

local function case_small_table_concat()
  local parts = {}
  for i = 1, N_SMALL do
    parts[i] = tostring(i)
  end
  return #table.concat(parts)
end

local function iso_ts_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function lua_id()
  return (_VERSION or "Lua"):gsub(" ", "")
end

local ver = io.popen("lua -v 2>&1"):read("*l") or lua_id()
-- "Lua 5.4.7  Copyright ..." → keep "Lua 5.4.7"
ver = ver:match("^(Lua [%d%.]+)") or ver

local ts = iso_ts_utc()
local lines = {}

local function emit(case, role, med, ops, ratio)
  local obj = string.format(
    '{"rule":"lu-string-concat-hot","case":"%s","role":"%s","lua":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}',
    case, role, ver, med, ops, ratio, ts
  )
  lines[#lines + 1] = obj
  io.stderr:write(string.format("  %s %s median=%.3f ms ops=%d ratio=%.3f\n", role, case, med, ops, ratio))
end

io.stderr:write(string.format(
  "lu-string-concat-hot evidence: %s warm=%d rounds=%d N_digits=%d N_chunk=%d N_small=%d\n",
  ver, WARM, ROUNDS, N_DIGITS, N_CHUNK, N_SMALL
))

io.stderr:write("-- pair A digits (fixture-shaped)\n")
local med_da, _ = time_many(case_digits_table_concat)
local med_db, _ = time_many(case_digits_concat)
emit("digits_table_concat", "after", med_da, N_DIGITS, 1)
emit("digits_concat_loop", "before", med_db, N_DIGITS, med_db / med_da)

io.stderr:write("-- pair B fixed 32-byte chunk\n")
local med_ca, _ = time_many(case_chunk_table_concat)
local med_cb, _ = time_many(case_chunk_concat)
emit("chunk32_table_concat", "after", med_ca, N_CHUNK, 1)
emit("chunk32_concat_loop", "before", med_cb, N_CHUNK, med_cb / med_ca)

io.stderr:write("-- pair C small N\n")
local med_sa, _ = time_many(case_small_table_concat)
local med_sb, _ = time_many(case_small_concat)
emit("small_n_table_concat", "after", med_sa, N_SMALL, 1)
emit("small_n_concat_loop", "before", med_sb, N_SMALL, med_sb / math.max(med_sa, 1e-9))

local out_path = OUT:gsub("/+$", "") .. "/lu-string-concat-hot.jsonl"
local f = assert(io.open(out_path, "w"))
for _, line in ipairs(lines) do
  f:write(line .. "\n")
end
f:close()
io.stderr:write("wrote " .. out_path .. "\n")
for _, line in ipairs(lines) do
  print(line)
end
