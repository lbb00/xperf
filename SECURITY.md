# Security Policy

## Supported versions

Security fixes are accepted against the latest commit on the default branch of
this repository.

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

Report through **GitHub private vulnerability reporting** on this repository:
`Security` → `Advisories` → `Report a vulnerability`.

If that control is not enabled, contact a maintainer privately on GitHub.
This tree does not publish a security mailbox. Do not invent one.

### What to include

- Affected package (any kit under `packages/`) and the repo version or commit if known
- Description and impact
- Reproduction steps or a minimal PoC when safe to share

You should receive an acknowledgement when maintainers are able to respond.
We will coordinate a fix and disclosure timeline with you.

## Scope notes

These kits are heuristic performance checkers and guides, not sandboxes or
security analyzers. Reports about false positives in lint rules belong in
ordinary issues (see the false-positive template), not security advisories,
unless the tool itself can be made to execute untrusted input unsafely.

## Maintainer checklist

1. Keep **private vulnerability reporting** enabled (`Settings` → `Security`).
2. Keep this file aligned with that control.
3. Do **not** add a `security@…` address unless that mailbox is real and monitored.
