// Copy the repo's Markdown into this app. Guides stay where they are.
// Code links point at GitHub. JSONL and the license files go in public/.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bundledLanguages } from 'shiki';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONTENT = path.join(ROOT, 'site-app', 'content', 'docs');
const PUBLIC = path.join(ROOT, 'site-app', 'public');
const DEFAULT_REPO = 'https://github.com/lbb00/xperf';
const LINK_RE = /(!?\[[^\]]*\]\()(<[^>]+>|[^)\s]+)([^)]*)(\))/g;
const DEF_RE = /^(\[[^\]]+\]:\s+)(\S+)(.*)$/;
const NAV_RE = /:\s+(\S+\.md)\s*$/;
const FENCE_RE = /^[ ]{0,3}(```|~~~)/;

const KIT_TITLES = {
  zperf: 'Zig',
  cperf: 'C',
  jsperf: 'JavaScript',
  jvmperf: 'Java',
  goperf: 'Go',
  pyperf: 'Python',
  swiftperf: 'Swift',
  arktsperf: 'ArkTS',
  cppperf: 'C++',
  csharpperf: 'C#',
  phpperf: 'PHP',
  rubyperf: 'Ruby',
  rustperf: 'Rust',
  kotlinperf: 'Kotlin',
  objcperf: 'Objective-C',
  dartperf: 'Dart',
  luaperf: 'Lua',
  beamperf: 'Elixir',
  nimperf: 'Nim',
};
const KIT_ORDER = Object.keys(KIT_TITLES);
const DOC_START = ['overview', 'quickstart', 'kits', 'smell-catalog', 'rule-regression'];
const DOC_METHOD = [
  'playbook',
  'rule-id-map',
  'static-check-sources',
  'roadmap-next',
  'release',
  'index',
  'doc-style',
  'branding',
];

let rewritten = 0;
const unresolved = [];
let staticFiles = new Set();

function repoUrl() {
  const explicit = (process.env.XPERF_REPO_URL || '').trim();
  if (explicit) return explicit.replace(/\/$/, '');
  const gh = (process.env.GITHUB_REPOSITORY || '').trim();
  if (gh) {
    const server = (process.env.GITHUB_SERVER_URL || 'https://github.com').replace(/\/$/, '');
    return `${server}/${gh}`;
  }
  return DEFAULT_REPO;
}

function gitFiles() {
  const out = execFileSync('git', ['ls-files', '-z', '-co', '--exclude-standard'], { cwd: ROOT });
  return out.toString('utf8').split('\0').filter(Boolean);
}

function shikiLangs() {
  const keys = new Set(Object.keys(bundledLanguages));
  for (const lang of Object.values(bundledLanguages)) {
    for (const alias of lang.aliases ?? []) keys.add(alias);
  }
  return keys;
}

const KNOWN_LANGS = shikiLangs();

function siteAnchor(frag) {
  const body = frag.startsWith('#') ? frag.slice(1) : frag;
  const slug = body
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, '')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '');
  if (!slug) return frag.startsWith('#') ? frag : `#${frag}`;
  return `#${slug}`;
}

function normRel(base, urlPath) {
  const parts = [];
  if (base && base !== '.') parts.push(...base.split('/'));
  for (const part of urlPath.split('/')) {
    if (part === '' || part === '.') continue;
    if (part === '..') {
      if (!parts.length) return null;
      parts.pop();
      continue;
    }
    parts.push(part);
  }
  return parts.join('/');
}

function pageDir(logical) {
  if (logical === 'index.md') return '.';
  const parent = path.posix.dirname(logical);
  return parent === '.' ? '.' : parent;
}

function relLink(fromLogical, toPath) {
  const origin = fromLogical === 'index.md' ? '.' : path.posix.dirname(fromLogical);
  return path.posix.relative(origin, toPath);
}

// `en/guide.md` and `zh-CN/guide.md` are the same page. The Chinese file is
// published as `guide.zh.md` next to the English one.
function publishPath(logical) {
  const parts = logical.split('/');
  if (parts.length < 2 || !parts.at(-1).endsWith('.md')) return logical;
  const parent = parts.at(-2);
  const name = parts.at(-1);
  if (parent === 'zh-CN') {
    const stem = name.slice(0, -'.md'.length);
    return [...parts.slice(0, -2), `${stem}.zh.md`].join('/');
  }
  if (parent === 'en') return [...parts.slice(0, -2), name].join('/');
  return logical;
}

function repoHas(target, repoSet) {
  if (repoSet.has(target)) return true;
  const prefix = `${target.replace(/\/$/, '')}/`;
  for (const item of repoSet) {
    if (item.startsWith(prefix)) return true;
  }
  return false;
}

function asPage(filePath) {
  const norm = filePath.replaceAll('\\', '/');
  if (norm === 'README.md' || norm.endsWith('/README.md')) {
    return `${norm.slice(0, -'README.md'.length)}index.md`;
  }
  return norm;
}

function classify(target, copied, repoSet) {
  if (target.endsWith('.md')) {
    const dest = asPage(target);
    if (copied.has(dest)) return ['page', dest];
    return ['missing', target];
  }
  if (staticFiles.has(target)) return ['static', target];
  const folder = target.replace(/\/$/, '');
  const readme = asPage(`${folder}/README.md`);
  if (copied.has(readme) && repoHas(folder, repoSet)) return ['page', readme];
  if (repoHas(target, repoSet)) return ['github', target];
  return ['missing', target];
}

function mapUrl(raw, logical, copied, repoSet, remote) {
  const body = raw.startsWith('<') && raw.endsWith('>') ? raw.slice(1, -1).trim() : raw;
  if (!body) return null;
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(body)) return null;
  const hash = body.indexOf('#');
  let urlPath = hash === -1 ? body : body.slice(0, hash);
  const frag = hash === -1 ? '' : body.slice(hash);
  let query = '';
  const queryAt = urlPath.indexOf('?');
  if (queryAt !== -1) {
    query = urlPath.slice(queryAt);
    urlPath = urlPath.slice(0, queryAt);
  }
  urlPath = urlPath.trim();
  if (!urlPath) {
    if (!frag) return null;
    const fixed = siteAnchor(frag);
    if (fixed === frag) return null;
    rewritten += 1;
    return fixed;
  }
  const target = normRel(pageDir(logical), urlPath);
  if (target == null) {
    unresolved.push(`${logical}: ${raw}`);
    return null;
  }
  const [kind, dest] = classify(target, copied, repoSet);
  if (kind === 'missing') {
    unresolved.push(`${logical}: ${raw}`);
    return null;
  }
  if (kind === 'static') {
    const base = (process.env.PAGES_BASE_PATH || '').trim().replace(/\/$/, '');
    rewritten += 1;
    return `${base}/${dest}${query}${frag}`;
  }
  if (kind === 'github') {
    const mode = repoSet.has(dest) ? 'blob' : 'tree';
    rewritten += 1;
    return `${remote}/${mode}/main/${dest}${frag}`;
  }
  const from = publishPath(logical);
  const publishedDest = publishPath(dest);
  const moved = from !== logical || publishedDest !== dest;
  const fixed = frag ? siteAnchor(frag) : '';
  if (!moved && dest === target) {
    if (!fixed || fixed === frag) return null;
    rewritten += 1;
    return `${urlPath}${query}${fixed}`;
  }
  rewritten += 1;
  if (moved) return `${relLink(from, publishedDest)}${query}${frag}`;
  return `${relLink(logical, dest)}${query}${fixed}`;
}

function rewriteChunk(chunk, logical, copied, repoSet, remote) {
  return chunk.replace(LINK_RE, (full, open, raw, extra, close) => {
    const next = mapUrl(raw, logical, copied, repoSet, remote);
    if (next == null) return full;
    return `${open}${next}${extra}${close}`;
  });
}

function rewriteLine(line, logical, copied, repoSet, remote) {
  const defn = DEF_RE.exec(line);
  if (defn) {
    const next = mapUrl(defn[2], logical, copied, repoSet, remote);
    if (next == null) return line;
    return `${defn[1]}${next}${defn[3]}`;
  }
  // Keep [`code`](url) intact so the URL can be rewritten. Other code spans stay literal.
  const masked = [];
  let work = '';
  let i = 0;
  while (i < line.length) {
    if (line[i] !== '`') {
      work += line[i];
      i += 1;
      continue;
    }
    let j = i;
    while (j < line.length && line[j] === '`') j += 1;
    const token = line.slice(i, j);
    const end = line.indexOf(token, j);
    if (end === -1) {
      work += line.slice(i);
      break;
    }
    const span = line.slice(i, end + token.length);
    const inLabel = line[i - 1] === '[' && line[end + token.length] === ']';
    if (inLabel) work += span;
    else {
      work += `\u0000${masked.length}\u0000`;
      masked.push(span);
    }
    i = end + token.length;
  }
  work = rewriteChunk(work, logical, copied, repoSet, remote);
  if (!masked.length) return work;
  return work.replace(/\u0000(\d+)\u0000/g, (_, n) => masked[Number(n)]);
}

function linesKeep(text) {
  if (!text) return [];
  const parts = text.split(/(\r\n|\n)/);
  const lines = [];
  for (let i = 0; i < parts.length; i += 2) {
    const nl = parts[i + 1] ?? '';
    if (parts[i] === '' && !nl) break;
    lines.push(parts[i] + nl);
  }
  return lines;
}

function rewriteText(text, logical, copied, repoSet, remote) {
  let fence = false;
  let out = '';
  for (const line of linesKeep(text)) {
    const probe = line.replace(/\r\n$|\n$/, '');
    const nl = line.slice(probe.length);
    if (FENCE_RE.test(probe)) {
      fence = !fence;
      out += line;
      continue;
    }
    if (fence) {
      out += line;
      continue;
    }
    out += rewriteLine(probe, logical, copied, repoSet, remote) + nl;
  }
  return out;
}

function escapeLine(line) {
  let out = '';
  let i = 0;
  while (i < line.length) {
    if (line[i] === '`') {
      let j = i + 1;
      while (j < line.length && line[j] === '`') j += 1;
      const ticks = line.slice(i, j);
      const close = line.indexOf(ticks, j);
      if (close < 0) {
        out += line.slice(i);
        break;
      }
      out += line.slice(i, close + ticks.length);
      i = close + ticks.length;
      continue;
    }
    if (line.startsWith('<http://', i) || line.startsWith('<https://', i) || line.startsWith('<mailto:', i)) {
      const end = line.indexOf('>', i);
      if (end >= 0) {
        out += line.slice(i, end + 1);
        i = end + 1;
        continue;
      }
    }
    const ch = line[i];
    const prev = i ? line[i - 1] : '';
    if (ch === '<' && prev !== '\\') out += '\\<';
    else if ((ch === '{' || ch === '}') && prev !== '\\') out += `\\${ch}`;
    else out += ch;
    i += 1;
  }
  return out;
}

function escapeMdx(text) {
  let fence = false;
  let out = '';
  for (const line of linesKeep(text)) {
    const probe = line.replace(/\r\n$|\n$/, '');
    const nl = line.slice(probe.length);
    if (FENCE_RE.test(probe)) {
      fence = !fence;
      out += line;
      continue;
    }
    if (fence) {
      out += line;
      continue;
    }
    out += escapeLine(probe) + nl;
  }
  return out;
}

function splitH1(text) {
  let fence = false;
  const lines = linesKeep(text);
  for (let i = 0; i < lines.length; i += 1) {
    const probe = lines[i].replace(/\r\n$|\n$/, '');
    if (FENCE_RE.test(probe)) {
      fence = !fence;
      continue;
    }
    if (fence || !probe.trim()) continue;
    if (probe.startsWith('# ')) {
      const title = probe.slice(2).trim();
      const rest = lines.slice(0, i).concat(lines.slice(i + 1));
      if (i < rest.length && !rest[i].trim()) rest.splice(i, 1);
      return [title, rest.join('')];
    }
    return [null, text];
  }
  return [null, text];
}

function normalizeFences(text) {
  let fence = false;
  let out = '';
  for (const line of linesKeep(text)) {
    let probe = line.replace(/\r\n$|\n$/, '');
    const nl = line.slice(probe.length);
    const matched = FENCE_RE.exec(probe);
    if (matched && !fence) {
      const info = probe.slice(matched[0].length).trim();
      const token = info ? info.split(' ')[0] : '';
      if (token && token !== 'mermaid' && ((KNOWN_LANGS.size && !KNOWN_LANGS.has(token)) || token === 'proguard')) {
        probe = `${probe.slice(0, matched[0].length)}text${info.slice(token.length)}`;
      }
    }
    if (matched) fence = !fence;
    out += probe + nl;
  }
  return out;
}

function prepareMd(text, logical, copied, repoSet, remote) {
  let body = text.replace(/^\uFEFF/, '');
  body = normalizeFences(body);
  body = rewriteText(body, logical, copied, repoSet, remote);
  if (body.startsWith('---\n') || body.startsWith('---\r\n')) return body;
  let title;
  [title, body] = splitH1(body);
  body = escapeMdx(body);
  if (!title) title = path.posix.basename(logical, '.md');
  return `---\ntitle: ${JSON.stringify(title)}\n---\n\n${body}`;
}

const ZH_TITLE = {
  Guides: '指南',
  Method: '方法',
  Languages: '语言',
  Project: '项目',
  Lint: '检查器',
  Evidence: '证据',
};

function zhMeta(payload) {
  const zh = { ...payload };
  let changed = false;
  if (typeof payload.title === 'string' && ZH_TITLE[payload.title]) {
    zh.title = ZH_TITLE[payload.title];
    changed = true;
  }
  if (Array.isArray(payload.pages)) {
    zh.pages = payload.pages.map((item) => {
      if (typeof item !== 'string') return item;
      const sep = /^---(.+)---$/.exec(item);
      if (!sep || !ZH_TITLE[sep[1]]) return item;
      changed = true;
      return `---${ZH_TITLE[sep[1]]}---`;
    });
  }
  return changed ? zh : null;
}

function dumpMeta(directory, payload) {
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'meta.json'), `${JSON.stringify(payload, null, 2)}\n`);
  const zh = zhMeta(payload);
  if (zh) fs.writeFileSync(path.join(directory, 'meta.zh.json'), `${JSON.stringify(zh, null, 2)}\n`);
}

function hasMd(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (hasMd(full)) return true;
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      return true;
    }
  }
  return false;
}

function byCodePoint(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

function writeKitDocs(docsDir) {
  const files = [];
  const folders = [];
  for (const entry of fs.readdirSync(docsDir, { withFileTypes: true })) {
    if (entry.name === 'meta.json' || entry.name === 'meta.zh.json' || entry.name.startsWith('.')) continue;
    if (entry.name.endsWith('.zh.md')) continue;
    if (entry.isDirectory()) {
      if (entry.name === 'zh-CN' || entry.name === 'en') continue;
      folders.push(entry.name);
    } else if (entry.name.endsWith('.md')) {
      files.push(entry.name.slice(0, -'.md'.length));
    }
  }
  const preferred = ['rule-ids', 'corpus', 'evidence-policy', 'community-tooling'];
  const rank = (name) => {
    if (name.includes('performance-guide')) return [0, name];
    const index = preferred.indexOf(name);
    if (index >= 0) return [1, index, name];
    return [2, name];
  };
  const cmp = (a, b) => {
    const ra = rank(a);
    const rb = rank(b);
    const n = Math.max(ra.length, rb.length);
    for (let i = 0; i < n; i += 1) {
      if (ra[i] === undefined) return -1;
      if (rb[i] === undefined) return 1;
      if (ra[i] < rb[i]) return -1;
      if (ra[i] > rb[i]) return 1;
    }
    return 0;
  };
  files.sort(cmp);
  folders.sort(byCodePoint);
  dumpMeta(docsDir, { pages: [...files, ...folders, '...'] });
}

function writeKit(kitDir) {
  const pages = [];
  if (fs.existsSync(path.join(kitDir, 'index.md'))) pages.push('index');
  const docsDir = path.join(kitDir, 'docs');
  if (fs.existsSync(docsDir) && fs.statSync(docsDir).isDirectory() && hasMd(docsDir)) {
    writeKitDocs(docsDir);
    pages.push('...docs');
  }
  const children = fs.readdirSync(kitDir, { withFileTypes: true }).sort((a, b) => byCodePoint(a.name, b.name));
  for (const child of children) {
    if (!child.isDirectory() || !child.name.endsWith('-lint')) continue;
    const lintDir = path.join(kitDir, child.name);
    if (!hasMd(lintDir)) continue;
    dumpMeta(lintDir, { title: 'Lint' });
    pages.push(child.name);
  }
  const evidence = path.join(kitDir, 'evidence');
  if (fs.existsSync(evidence) && fs.statSync(evidence).isDirectory() && hasMd(evidence)) {
    dumpMeta(evidence, { title: 'Evidence' });
    pages.push('evidence');
  }
  pages.push('...');
  const name = path.basename(kitDir);
  dumpMeta(kitDir, { title: KIT_TITLES[name] ?? name, pages });
}

function writeSidebar() {
  const docsDir = path.join(CONTENT, 'docs');
  if (fs.existsSync(docsDir)) {
    const present = new Set();
    for (const entry of fs.readdirSync(docsDir, { withFileTypes: true })) {
      if (entry.name === 'meta.json' || entry.name === 'meta.zh.json' || entry.name.startsWith('.')) continue;
      if (entry.name.endsWith('.zh.md')) continue;
      present.add(entry.name.endsWith('.md') ? entry.name.slice(0, -3) : entry.name);
    }
    const pages = DOC_START.filter((name) => present.has(name));
    const method = DOC_METHOD.filter((name) => present.has(name));
    if (method.length) pages.push('---Method---', ...method);
    pages.push('...');
    dumpMeta(docsDir, { title: 'Guides', pages });
  }

  const packagesDir = path.join(CONTENT, 'packages');
  if (fs.existsSync(packagesDir)) {
    const kits = fs
      .readdirSync(packagesDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
      .sort((a, b) => byCodePoint(a.name, b.name));
    for (const kit of kits) writeKit(path.join(packagesDir, kit.name));
    const ordered = KIT_ORDER.filter((name) => fs.existsSync(path.join(packagesDir, name)));
    dumpMeta(packagesDir, { title: 'Languages', pages: [...ordered, '...'] });
  }

  const project = ['CONTRIBUTING', 'CHANGELOG', 'SECURITY', 'CODE_OF_CONDUCT', 'AGENT'];
  const rootPages = ['index', 'docs', 'packages', '---Project---'];
  for (const name of project) {
    if (fs.existsSync(path.join(CONTENT, `${name}.md`))) rootPages.push(name);
  }
  rootPages.push('...');
  dumpMeta(CONTENT, { pages: rootPages });
}

function skip(filePath) {
  return (
    `/${filePath}`.includes('/guide-src/') ||
    filePath.startsWith('pages/') ||
    filePath.startsWith('site-app/') ||
    filePath.startsWith('site-src/') ||
    filePath.startsWith('.github/')
  );
}

function assemble() {
  fs.rmSync(CONTENT, { recursive: true, force: true });
  fs.rmSync(PUBLIC, { recursive: true, force: true });
  fs.mkdirSync(CONTENT, { recursive: true });
  fs.mkdirSync(PUBLIC, { recursive: true });
  const remote = repoUrl();
  const tracked = gitFiles();
  const repoSet = new Set(tracked);
  const copied = new Set();
  const mdFiles = [];
  const files = [];
  const publishedSeen = new Map();
  for (const filePath of tracked) {
    if (skip(filePath)) continue;
    if (filePath.endsWith('.md')) {
      const logical = asPage(filePath);
      const published = publishPath(logical);
      const previous = publishedSeen.get(published);
      if (previous) {
        console.error(`build-pages: ${logical} and ${previous} both publish to ${published}`);
        process.exit(1);
      }
      publishedSeen.set(published, logical);
      mdFiles.push([filePath, logical, published]);
      copied.add(logical);
    } else if (filePath.endsWith('.jsonl') || filePath === 'LICENSE' || filePath === 'NOTICE') {
      files.push(filePath);
    }
  }
  staticFiles = new Set(files);

  for (const srcRel of files) {
    const dest = path.join(PUBLIC, srcRel);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(path.join(ROOT, srcRel), dest);
  }
  for (const [srcRel, logical, published] of mdFiles) {
    const text = fs.readFileSync(path.join(ROOT, srcRel), 'utf8');
    const body = prepareMd(text, logical, copied, repoSet, remote);
    const dest = path.join(CONTENT, published);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, body);
  }
  writeSidebar();
  checkNav(copied);
  console.log(
    `build-pages: assembled ${mdFiles.length} pages, ${files.length} files, rewrote ${rewritten} links`,
  );
  if (unresolved.length) {
    console.error(`build-pages: ${unresolved.length} links left unchanged\n${unresolved.slice(0, 40).join('\n')}`);
  }
}

function checkNav(copied) {
  const missing = [];
  const text = fs.readFileSync(path.join(ROOT, 'mkdocs.yml'), 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const match = NAV_RE.exec(line);
    if (!match) continue;
    if (!copied.has(asPage(match[1]))) missing.push(match[1]);
  }
  if (missing.length) {
    console.error(`build-pages: nav entries missing from the site\n${missing.join('\n')}`);
    process.exit(1);
  }
}

const cmd = process.argv[2] ?? 'build';
if (cmd !== 'build' && cmd !== 'serve') {
  console.error('usage: node assemble.js [build|serve]');
  process.exit(1);
}
assemble();
