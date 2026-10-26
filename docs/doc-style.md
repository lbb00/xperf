# Documentation style

Enforced by `bash scripts/doc-check.sh` and `bash scripts/build-guides.sh --check` (both run in CI). Fix at the source; do not weaken the checks.

## All Markdown

- One `# H1` as the first line; headings never skip a level; ATX (`#`) headings only.
- No trailing whitespace, no CRLF, exactly one final newline.
- Relative links must resolve. Do not link to files outside the repository.
- Lists use `-`; code fences carry a language tag where one applies.
- English everywhere except `zh-CN/` directories.

## Per package

| File | Required |
|------|----------|
| `README.md` | `## Run lint` and `## Layout` (suggested order: Contents, Focus, Run lint, Layout) |
| `docs/corpus.md` | `## Pins` first; later sections are dated notes |
| `docs/evidence-policy.md` | `## Gate`, then `## Current map` (heading carries no date or version; put "as of <date>" in the first line of the section) |
| `docs/rule-ids.md` | one H1; tombstones under `## Removed (tombstone; never reuse)` |
| `evidence/<slug>.md` | `Claim`, `How measured`, `Runtime` table, result; or `Status` / `Reason` / `Unblock` for pending rules |

## Guides

`docs/guide-src/*.md` (or `guide-src/<lang>/*.md`) is the only source. The guide itself is generated:

```sh
bash scripts/build-guides.sh          # rewrite guides from guide-src
bash scripts/build-guides.sh --check  # fail if a guide was edited by hand
```

- Shards are concatenated byte for byte, so each shard ends with a blank line only if the guide needs one there.
- Links inside a shard are written relative to the generated guide, not to `guide-src/`.
- Shard names are `NN_topic.md`; `00_head.md` opens the guide.
