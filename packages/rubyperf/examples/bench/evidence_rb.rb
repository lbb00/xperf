#!/usr/bin/env ruby
# Evidence for rb-string-plus-in-loop–rb-file-read-in-loop → packages/rubyperf/evidence/
require 'benchmark'

WARM = (ENV['RB_WARM'] || '3').to_i
ROUNDS = (ENV['RB_ROUNDS'] || '9').to_i
OUT = ENV['EVIDENCE_DIR'] || File.expand_path('../../evidence', __dir__)

def median(xs)
  a = xs.sort
  n = a.length
  return 0.0 if n == 0
  n.odd? ? a[n / 2] : 0.5 * (a[n / 2 - 1] + a[n / 2])
end

def time_many
  WARM.times { yield }
  samples = []
  sink = 0
  ROUNDS.times do
    GC.start
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sink += yield
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    samples << (t1 - t0) * 1e3
  end
  median(samples)
end

ver = "Ruby #{RUBY_VERSION}"
ts = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
lines = Hash.new { |h, k| h[k] = [] }

emit = lambda do |rule, case_name, role, med, ops, ratio|
  obj = format(
    '{"rule":"%s","case":"%s","role":"%s","ruby":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}',
    rule, case_name, role, ver, med, ops, ratio, ts
  )
  lines[rule] << obj
  warn format('  %s %s %s median=%.3f ms ops=%d ratio=%.3f', rule, role, case_name, med, ops, ratio)
end

# rb-string-plus-in-loop string += vs <<
n1 = (ENV['RB001_N'] || '50000').to_i
parts = Array.new(n1, 'x')
warn "rb-string-plus-in-loop str-plus n=#{n1}"
med1a = time_many do
  s = +''
  parts.each { |p| s << p }
  s.length
end
med1b = time_many do
  s = ''
  parts.each { |p| s += p }
  s.length
end
emit.call('rb-string-plus-in-loop', 'shovel', 'after', med1a, n1, 1.0)
emit.call('rb-string-plus-in-loop', 'str_plus', 'before', med1b, n1, med1b / [med1a, 1e-9].max)

n1s = (ENV['RB001_N_SMALL'] || '100').to_i
parts_s = parts[0, n1s]
med1sa = time_many { s = +''; parts_s.each { |p| s << p }; s.length }
med1sb = time_many { s = ''; parts_s.each { |p| s += p }; s.length }
emit.call('rb-string-plus-in-loop', 'small_shovel', 'after', med1sa, n1s, 1.0)
emit.call('rb-string-plus-in-loop', 'small_str_plus', 'before', med1sb, n1s, med1sb / [med1sa, 1e-9].max)

# rb-array-plus-rebind array + [x] vs <<
n2 = (ENV['RB002_N'] || '20000').to_i
items = (0...n2).to_a
warn "rb-array-plus-rebind array-plus n=#{n2}"
med2a = time_many do
  a = []
  items.each { |x| a << x }
  a.length
end
med2b = time_many do
  a = []
  items.each { |x| a = a + [x] }
  a.length
end
emit.call('rb-array-plus-rebind', 'shovel', 'after', med2a, n2, 1.0)
emit.call('rb-array-plus-rebind', 'array_plus_rebind', 'before', med2b, n2, med2b / [med2a, 1e-9].max)

n2s = (ENV['RB002_N_SMALL'] || '100').to_i
items_s = items[0, n2s]
med2sa = time_many { a = []; items_s.each { |x| a << x }; a.length }
med2sb = time_many { a = []; items_s.each { |x| a = a + [x] }; a.length }
emit.call('rb-array-plus-rebind', 'small_shovel', 'after', med2sa, n2s, 1.0)
emit.call('rb-array-plus-rebind', 'small_array_plus', 'before', med2sb, n2s, med2sb / [med2sa, 1e-9].max)

# rb-puts-in-loop puts in loop vs join (stdout to /dev/null)
n3 = (ENV['RB003_N'] || '20000').to_i
warn "rb-puts-in-loop puts-loop n=#{n3}"
med3a = time_many do
  File.open('/dev/null', 'w') do |f|
    buf = (0...n3).map(&:to_s)
    f.puts(buf.join("\n"))
  end
  n3
end
med3b = time_many do
  File.open('/dev/null', 'w') do |f|
    n3.times { |i| f.puts(i) }
  end
  n3
end
emit.call('rb-puts-in-loop', 'join_once', 'after', med3a, n3, 1.0)
emit.call('rb-puts-in-loop', 'puts_each', 'before', med3b, n3, med3b / [med3a, 1e-9].max)

Dir.mkdir(OUT) unless Dir.exist?(OUT)
lines.each do |rule, objs|
  path = File.join(OUT, "#{rule}.jsonl")
  File.write(path, objs.join("\n") + "\n")
  warn "wrote #{path}"
  puts objs
end
