#!/usr/bin/env lua
-- luaperf-lint — heuristic Lua performance checker
local MSG = {
  ["lu-table-insert-in-loop"] = "table.insert / grow in loop; prefer pre-sized index writes",
  ["lu-string-concat-in-loop"] = "string .. in loop; prefer table.concat",
  ["lu-print-in-loop"] = "print in loop; gate or buffer",
}
local sev = { ["lu-table-insert-in-loop"] = "off", ["lu-string-concat-in-loop"] = "error", ["lu-print-in-loop"] = "hint" }

local function usage(code)
  io.stderr:write("Usage: luaperf-lint.lua PATH... [options]\n"
    .. "  --format text|json\n"
    .. "  --severity RULE=error|hint|off\n"
    .. "  --strict-hints\n"
    .. "  --no-fail\n")
  os.exit(code)
end

local function apply_sev(spec)
  local rule, level = spec:match("^([^=]+)=([^=]+)$")
  if not rule or not sev[rule] then return false end
  if level ~= "off" and level ~= "hint" and level ~= "error" then return false end
  sev[rule] = level
  return true
end

local function strip_comment(line)
  local out, in_str, q = {}, false, nil
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if in_str then
      out[#out+1] = c
      if c == "\\" and i < #line then
        out[#out+1] = line:sub(i+1, i+1)
        i = i + 2
      else
        if c == q then in_str = false end
        i = i + 1
      end
    else
      if c == '"' or c == "'" then
        in_str = true
        q = c
        out[#out+1] = c
        i = i + 1
      elseif c == "-" and line:sub(i+1, i+1) == "-" then
        break
      else
        out[#out+1] = c
        i = i + 1
      end
    end
  end
  return table.concat(out)
end

local function scan_file(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local findings = {}
  local depth, in_loop = 0, 0
  local line_no = 0
  for raw in f:lines() do
    line_no = line_no + 1
    local code = strip_comment(raw)
    local opens = select(2, code:gsub("[{%(]", "")) -- brace and paren for do-less? use do/end
    -- Lua uses do/end and for/while/repeat
    local do_n = 0
    for _ in code:gmatch("%f[%w]do%f[%W]") do do_n = do_n + 1 end
    local end_n = 0
    for _ in code:gmatch("%f[%w]end%f[%W]") do end_n = end_n + 1 end
    local function_n = 0
    for _ in code:gmatch("%f[%w]function%f[%W]") do function_n = function_n + 1 end
    local then_n = 0
    for _ in code:gmatch("%f[%w]then%f[%W]") do then_n = then_n + 1 end
    local repeat_n = 0
    for _ in code:gmatch("%f[%w]repeat%f[%W]") do repeat_n = repeat_n + 1 end
    local until_n = 0
    for _ in code:gmatch("%f[%w]until%f[%W]") do until_n = until_n + 1 end
    local loop_here = code:match("%f[%w]for%f[%W]") or code:match("%f[%w]while%f[%W]") or code:match("%f[%w]repeat%f[%W]")
    if loop_here then
      in_loop = depth + 1
    end
    if in_loop > 0 and depth >= in_loop then
      if code:find("table%.insert%s*%(") then
        findings[#findings+1] = { rule="lu-table-insert-in-loop", path=path, line=line_no, message=MSG["lu-table-insert-in-loop"] }
      end
      -- "lu-string-concat-in-loop": string accumulation only (s = s .. x); ident boundary so
      -- ineligible_key = key .. x does not match as key = key ..
      do
        local pos = 1
        while true do
          local s, e = code:find("([%w_%.]+)%s*=%s*%1%s*%.%.", pos)
          if not s then break end
          if s == 1 or not code:sub(s - 1, s - 1):match("[%w_]") then
            findings[#findings+1] = { rule="lu-string-concat-in-loop", path=path, line=line_no, message=MSG["lu-string-concat-in-loop"] }
            break
          end
          pos = s + 1
        end
      end
      -- "lu-print-in-loop": bare print(...), not to_print / buffered_print / ngx_print
      do
        local ps = code:find("print%s*%(")
        if ps and (ps == 1 or not code:sub(ps - 1, ps - 1):match("[%w_]")) then
          findings[#findings+1] = { rule="lu-print-in-loop", path=path, line=line_no, message=MSG["lu-print-in-loop"] }
        end
      end
    end
    depth = depth + do_n + function_n + then_n + repeat_n - end_n - until_n
    if depth < 0 then depth = 0 end
    if in_loop > 0 and depth < in_loop then in_loop = 0 end
  end
  f:close()
  return findings
end

local function skip_dir(name)
  return name == ".git" or name == "fixtures" or name == "node_modules" or name == "vendor"
    or name == "spec" or name == "t" or name == "test" or name == "tests"
    or name == "examples" or name == "example" or name == "docs" or name == "bench" or name == "benchmark"
    or name == "benchmarks" or name == ".ci" or name == "autodoc" or name == "tlib"
    or name == "cli" or name == "bin" or name == "scripts"
end

local function path_skipped(path)
  for seg in string.gmatch(path, "[^/]+") do
    if skip_dir(seg) then return true end
  end
  return false
end

local function scan_path(root)
  local attr = io.open(root, "r")
  if not attr then return {} end
  -- crude: if ends with .lua treat as file
  if root:match("%.lua$") then
    attr:close()
    return scan_file(root)
  end
  attr:close()
  local all = {}
  local function walk(dir)
    local p = io.popen('find "' .. dir:gsub('"', '\\"') .. '" -type f -name "*.lua" 2>/dev/null')
    if not p then return end
    local root = dir:gsub("/+$", "")
    for path in p:lines() do
      local rel = path
      if path:sub(1, #root) == root and #path > #root then
        rel = path:sub(#root + 2)
      end
      if not path_skipped(rel) then
        for _, f in ipairs(scan_file(path)) do
          all[#all+1] = f
        end
      end
    end
    p:close()
  end
  walk(root)
  return all
end

-- CLI
local args = {...}
if #args == 0 then usage(2) end
local format, strict_hints, no_fail = "text", false, false
local paths = {}
local i = 1
while i <= #args do
  local a = args[i]
  if a == "-h" or a == "--help" then usage(0)
  elseif a == "--format" then i=i+1; format = args[i] or usage(2)
  elseif a:match("^%-%-format=") then format = a:match("^%-%-format=(.*)$")
  elseif a == "--severity" then i=i+1; if not apply_sev(args[i] or "") then usage(2) end
  elseif a:match("^%-%-severity=") then if not apply_sev(a:match("^%-%-severity=(.*)$")) then usage(2) end
  elseif a == "--strict-hints" then strict_hints = true
  elseif a == "--no-fail" then no_fail = true
  elseif a:sub(1,1) == "-" then usage(2)
  else paths[#paths+1] = a end
  i = i + 1
end
if #paths == 0 then usage(2) end

local findings = {}
for _, p in ipairs(paths) do
  for _, f in ipairs(scan_path(p)) do findings[#findings+1] = f end
end

local nerr, nhint = 0, 0
local lines, rows = {}, {}
for _, f in ipairs(findings) do
  local level = sev[f.rule] or "hint"
  if level ~= "off" then
    if level == "error" then nerr = nerr + 1 else nhint = nhint + 1 end
    if format == "json" then
      rows[#rows+1] = string.format(
        '{"rule":"%s","severity":"%s","path":"%s","line":%d,"message":"%s"}',
        f.rule, level, f.path, f.line, f.message)
    else
      lines[#lines+1] = string.format("%s:%d: %s %s: %s", f.path, f.line, level, f.rule, f.message)
    end
  end
end
if format == "json" then
  io.write("[" .. table.concat(rows, ",") .. "]\n")
else
  if #lines > 0 then io.write(table.concat(lines, "\n") .. "\n") end
  local shown = nerr + nhint
  if shown > 0 then
    io.stderr:write(string.format("%d finding(s) (%d error, %d hint)\n", shown, nerr, nhint))
  else
    io.stderr:write("ok\n")
  end
end
if no_fail then os.exit(0) end
if nerr > 0 or (strict_hints and nhint > 0) then os.exit(1) end
os.exit(0)
