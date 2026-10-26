# phpperf changelog

## 2026-10-22

- **ph-array-merge-rebind** default severity **hint → error** after G4 microbench on PHP 8.4.26
  (`evidence/ph-array-merge-rebind.md` + `ph-array-merge-rebind.jsonl`; harness `examples/bench/evidence_ph002.php`).
- Skip directory segment `bench` in corpus walks (alongside fixtures/vendor), so evidence
  harnesses under `examples/bench/` do not self-fire.
- Docs: evidence-policy map, rule-regression, guide severity table, corpus note.

## 2026-10-22

- G3 reverse-opt: path/file skips; ph-array-merge-rebind narrowed to same-var growing `$a = array_merge($a, …)`.

## Scaffold

- Initial ph-string-dot-in-loop–ph-echo-in-loop heuristic checker.
