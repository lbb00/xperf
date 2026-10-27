#!/usr/bin/env lua
-- Evidence microbench for lu-print-hot → packages/luaperf/evidence/lu-print-hot.jsonl
-- Smell: print(i) inside a numeric for; fix: quiet accumulate / print once / buffer then one write.
-- Timer: os.clock() CPU seconds.
-- IMPORTANT: Lua 5.4 print() writes the C stdout FILE*, not io.stdout. We replace
-- _G.print so every measured call goes to /dev/null (reproducible; not TTY-bound).

local ROUNDS = tonumber(os.getenv("LU003_ROUNDS") or "9")
local WARM = tonumber(os.getenv("LU003_WARM") or "3")
local N = tonumber(os.getenv("LU003_N") or "20000")
local N_SMALL = tonumber(os.getenv("LU003_N_SMALL") or "100")

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    local p = src:sub(2)
    return p:match("(.+)/[^/]+$") or "."
  end
  return "."
end
local OUT = os.getenv("EVIDENCE_DIR") or (script_dir() .. "/../../evidence")

local null_out = assert(io.open("/dev/null", "w"))
-- Match print semantics: tostring each arg, tab-separated, trailing newline.
_G.print = function(...)
  local n = select("#", ...)
  for i = 1, n do
    null_out:write(tostring(select(i, ...)))
    if i < n then null_out:write("\t") end
  end
  null_out:write("\n")
end

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
    sink = sink + (fn() or 0)
    local t1 = os.clock()
    samples[r] = (t1 - t0) * 1e3
  end
  if sink ~= sink then error("nan sink") end
  return median(samples), sink
end

-- Pair A (fixture-shaped): print(i) each iter vs quiet sum + print once after
local function case_print_in_loop()
  for i = 1, N do
    print(i)
  end
  return N
end

local function case_quiet_then_print_once()
  local s = 0
  for i = 1, N do
    s = s + i
  end
  print(s)
  return s
end

-- Pair B: buffer lines then one print
local function case_buffer_then_one_print()
  local parts = {}
  for i = 1, N do
    parts[i] = tostring(i)
  end
  print(table.concat(parts, "\n"))
  return #parts
end

-- Pair C: small N
local function case_small_print_in_loop()
  for i = 1, N_SMALL do
    print(i)
  end
  return N_SMALL
end

local function case_small_quiet_once()
  local s = 0
  for i = 1, N_SMALL do
    s = s + i
  end
  print(s)
  return s
end

local function iso_ts_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local ver_line = io.popen("lua -v 2>&1"):read("*l") or (_VERSION or "Lua")
local ver = ver_line:match("^(Lua [%d%.]+)") or ver_line

local ts = iso_ts_utc()
local lines = {}

local function emit(case, role, med, ops, ratio)
  local obj = string.format(
    '{"rule":"lu-print-hot","case":"%s","role":"%s","lua":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"stdout":"/dev/null","ts":"%s"}',
    case, role, ver, med, ops, ratio, ts
  )
  lines[#lines + 1] = obj
  io.stderr:write(string.format("  %s %s median=%.3f ms ops=%d ratio=%.3f\n", role, case, med, ops, ratio))
end

io.stderr:write(string.format(
  "lu-print-hot evidence: %s warm=%d rounds=%d N=%d N_small=%d stdout=/dev/null (via _G.print override)\n",
  ver, WARM, ROUNDS, N, N_SMALL
))

io.stderr:write("-- pair A print-in-loop vs quiet+once (fixture-shaped)\n")
local med_qa, _ = time_many(case_quiet_then_print_once)
local med_pb, _ = time_many(case_print_in_loop)
emit("quiet_then_print_once", "after", med_qa, N, 1)
emit("print_in_loop", "before", med_pb, N, med_pb / math.max(med_qa, 1e-9))

io.stderr:write("-- pair B buffer then one print\n")
local med_ba, _ = time_many(case_buffer_then_one_print)
-- re-time before for this pair so ratio uses a fresh sample set
local med_pb2, _ = time_many(case_print_in_loop)
emit("buffer_then_one_print", "after", med_ba, N, 1)
emit("print_in_loop_vs_buffer", "before", med_pb2, N, med_pb2 / math.max(med_ba, 1e-9))

io.stderr:write("-- pair C small N\n")
local med_sa, _ = time_many(case_small_quiet_once)
local med_sb, _ = time_many(case_small_print_in_loop)
emit("small_quiet_once", "after", med_sa, N_SMALL, 1)
emit("small_print_in_loop", "before", med_sb, N_SMALL, med_sb / math.max(med_sa, 1e-9))

local out_path = OUT:gsub("/+$", "") .. "/lu-print-hot.jsonl"
local f = assert(io.open(out_path, "w"))
for _, line in ipairs(lines) do
  f:write(line .. "\n")
end
f:close()
null_out:flush()

io.stderr:write("wrote " .. out_path .. "\n")
-- Restore a real print for the operator-facing JSONL echo (optional; write via io.stderr+file only)
for _, line in ipairs(lines) do
  io.stderr:write(line .. "\n")
end
