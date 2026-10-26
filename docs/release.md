# Releases

## What we publish

On each `v*` tag, GitHub Actions builds a **source distribution**:

- Asset: `xperf-<tag>-packages.tar.gz` (example: `xperf-v0.1.0-packages.tar.gz`)
- Contents: `packages/`, `docs/`, `site-app/`, `pages/`, `mkdocs.yml`, root docs (`README.md`, `LICENSE`, `NOTICE`, `AGENT.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`), and `scripts/`
- Checksum: `xperf-<tag>-packages.tar.gz.sha256`

Corpora are not packaged in the source tarball. No bench binaries. No npm / crates.io / Maven uploads in v0.1.

## What we do not publish (yet)

| Kind | Why |
|------|-----|
| Registry packages for all 19 kits | Different toolchains; not one universal binary |
| Prebuilt lint binaries for every kit | Source-run (Node/Make/Go/Zig/Gradle/Cargo/…) is the supported path |

## How to cut a release

1. Land the change on `main` (CI green).
2. Tag: `git tag v0.1.0 && git push origin v0.1.0`
3. Workflow [release.yml](../.github/workflows/release.yml) runs `scripts/pack-source-dist.sh`, uploads assets, creates the GitHub Release.

Local dry-run: `bash scripts/pack-source-dist.sh v0.1.0 /tmp/xperf-dist`

`workflow_dispatch` can re-run packaging without a new tag.

## Documentation site

GitHub Pages builds the guides from `main`. Workflow: [pages.yml](../.github/workflows/pages.yml). The source tarball does not contain the generated HTML.

The build reads the repository name into the site URL (`https://<owner>.github.io/<repo>/`). Update the README link if the repository is renamed.

Local preview:

```sh
bash scripts/build-pages.sh serve
```

Open `http://localhost:3000/`. Needs Node.js 22 or newer. The command copies the Markdown into `site-app/content` (gitignored) and starts the docs app. The first page you open is compiled then.

The sidebar language control is English / 中文. English pages stay at `/`. Chinese pages are under `/zh/`. A page without a Chinese translation stays in English and says so.

## CI vs Release

| Workflow | When | Job |
|----------|------|-----|
| [ci.yml](../.github/workflows/ci.yml) | PR / push to main | Per-kit smoke/tests + `sync-check` |
| [pages.yml](../.github/workflows/pages.yml) | PR / push to main | Documentation site. Push to `main` also deploys GitHub Pages |
| [release.yml](../.github/workflows/release.yml) | `v*` tags (or manual) | Source tarball + checksum → GitHub Release |
