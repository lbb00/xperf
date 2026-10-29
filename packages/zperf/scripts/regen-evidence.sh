#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
EV="$ROOT/evidence"
mkdir -p "$EV"
cd "$BENCH"
zig build-exe -Ofast -Mroot=evidence_fill.zig -femit-bin=evidence_fill
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
./evidence_fill > /tmp/zperf_evidence_all.jsonl 2>/tmp/zperf_evidence_stderr.txt
python3 - "$TS" "$EV" <<'PY'
import json, sys
from pathlib import Path
from collections import defaultdict
ts, ev = sys.argv[1], Path(sys.argv[2])
rows = []
for line in Path("/tmp/zperf_evidence_all.jsonl").read_text().splitlines():
    if not line.strip():
        continue
    o = json.loads(line)
    o["ts"] = ts
    rows.append(o)
by = defaultdict(list)
for o in rows:
    by[o["rule"]].append(o)
# zp-large-struct-by-value is kept out of evidence/ (inconclusive)
skip = {"zp-large-struct-by-value"}
for rule, rs in by.items():
    if rule in skip:
        continue
    rs = sorted(rs, key=lambda r: 0 if r["role"] == "before" else 1)
    (ev / f"{rule}.jsonl").write_text("\n".join(json.dumps(r, separators=(",", ":")) for r in rs) + "\n")
# zp-per-packet-alloc shares zp-alloc-hot
if "zp-alloc-hot" in by:
    shared = []
    for o in sorted(by["zp-alloc-hot"], key=lambda r: 0 if r["role"] == "before" else 1):
        x = dict(o)
        x["rule"] = "zp-per-packet-alloc"
        x["case"] = "shared_with_ZP001_" + o["case"]
        shared.append(x)
    (ev / "zp-per-packet-alloc.jsonl").write_text("\n".join(json.dumps(r, separators=(",", ":")) for r in shared) + "\n")
print(f"wrote evidence jsonl under {ev} (ts={ts})")
PY
echo "Update matching .md medians if ratios moved. stderr: /tmp/zperf_evidence_stderr.txt"
