# CI

Nested GitHub Actions for standalone zperf were removed from the umbrella tree.

Use the root workflow: [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) (job `zperf`).

Historical SARIF and third-party lint wiring lived here. Do not re-add path-broken workflows that assume `packages/zperf` is the repository root.
