use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};

#[derive(Clone, Debug)]
pub struct Finding {
    pub rule: &'static str,
    pub path: String,
    pub line: usize,
    pub message: &'static str,
}

const MSG001: &str = "alloc/clone; reuse buffers when profiles show pressure — cost adds up even off a hot path";
const MSG003: &str = "println!/eprintln!; gate debug or buffer outside — cost adds up even off a hot path";
const MSG004: &str = "format! rebind accum; prefer with_capacity + write! — cost adds up even off a hot path";
const MSG006: &str = "collect::<Vec<_>>; reuse a buffer or avoid per-iter collect — cost adds up even off a hot path";
const MSG007: &str = "Regex::new; compile outside only when this pattern stays the same — cost adds up even off a hot path";
const MSG008: &str = "file open; open once when the path stays the same — cost adds up even off a hot path";
const MSG009: &str = "clock sample in a tight loop with no await; hoist only when this iteration does not need a fresh time";

/// When false (via --raw-paths), noise path skips + heuristics are disabled for baseline dumps.
pub static ENABLE_REVERSE_OPT: AtomicBool = AtomicBool::new(true);

fn is_rs(path: &Path) -> bool {
    path.extension().and_then(|e| e.to_str()) == Some("rs")
}

fn always_skip_dir(name: &str) -> bool {
    matches!(
        name,
        ".git" | "fixtures" | "target" | "node_modules" | "vendor"
    )
}

fn noise_skip_dir(name: &str) -> bool {
    matches!(
        name,
        "tests" | "test" | "benches" | "bench" | "benchmarks" | "examples"
            | "example" | "docs" | "doc" | "fuzz" | "testdata" | "snapshots"
    )
}

fn skip_dir(name: &str) -> bool {
    if always_skip_dir(name) {
        return true;
    }
    ENABLE_REVERSE_OPT.load(Ordering::Relaxed) && noise_skip_dir(name)
}

fn strip_line_comment(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut in_str = false;
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if in_str {
            out.push(c);
            if c == '\\' {
                if let Some(n) = chars.next() {
                    out.push(n);
                }
                continue;
            }
            if c == '"' {
                in_str = false;
            }
            continue;
        }
        if c == '"' {
            in_str = true;
            out.push(c);
            continue;
        }
        if c == '/' && chars.peek() == Some(&'/') {
            break;
        }
        out.push(c);
    }
    out
}

fn path_looks_testish(path: &Path) -> bool {
    let s = path.to_string_lossy();
    s.contains("/tests/")
        || s.contains("/test/")
        || s.contains("/benches/")
        || s.contains("/examples/")
        || s.contains("/fuzz/")
        || s.ends_with("_test.rs")
        || s.ends_with("_tests.rs")
        || s.ends_with("/tests.rs")
        || path.file_name().and_then(|f| f.to_str()) == Some("tests.rs")
}

fn string_builder_path_skip(path: &Path) -> bool {
    let s = path.to_string_lossy();
    if s.contains("/shells/") || s.contains("clap_complete") || s.contains("clap_mangen") {
        return true;
    }
    if s.contains("/error/format.rs")
        || s.contains("help_template.rs")
        || s.contains("debug_asserts.rs")
        || s.contains("styled_str.rs")
    {
        return true;
    }
    false
}

/// Cold CLI / shell skips for rs-collect-vec-hot — keep styled_str + textwrap (real wrap allocs).
fn cold_cli_path_skip(path: &Path) -> bool {
    let s = path.to_string_lossy();
    if s.contains("/shells/") || s.contains("clap_complete") || s.contains("clap_mangen") {
        return true;
    }
    if s.contains("/error/format.rs")
        || s.contains("help_template.rs")
        || s.contains("debug_asserts.rs")
    {
        return true;
    }
    false
}

/// G3 reverse-opt: only real loop heads — not `impl Trait for Type` or `for<'a>`.
fn is_real_loop_head(code: &str) -> bool {
    let t = code.trim_start();
    if t.starts_with("impl ") || t.contains(" impl ") {
        return false;
    }
    if t.contains("for <") || t.contains("for<'") || t.contains("for <'") {
        return false;
    }
    if let Some(i) = t.find("for") {
        let after = t[i + 3..].trim_start();
        if after.starts_with('<') {
            return false;
        }
    }
    let while_kw = code.contains("while ") || t.starts_with("while ") || t.starts_with("while(");
    let loop_kw =
        t.starts_with("loop ") || t.starts_with("loop{") || t == "loop" || code.contains(" loop {");
    let for_in = {
        if let Some(i) = code.find("for ") {
            let after = &code[i + 4..];
            after.contains(" in ") && !after.trim_start().starts_with('<')
        } else if t.starts_with("for ") {
            t[4..].contains(" in ")
        } else {
            false
        }
    };
    for_in || while_kw || loop_kw
}

fn rs001_signal(code: &str) -> bool {
    let vec_new = format!("Vec{}new", "::");
    let clone_m = format!(".clone{}", "()");
    let to_string_m = format!(".to_string{}", "()");
    let to_owned_m = format!(".to_owned{}", "()");
    if code.contains(&vec_new) || code.contains(&to_string_m) || code.contains(&to_owned_m) {
        return true;
    }
    if !code.contains(&clone_m) {
        return false;
    }
    if !ENABLE_REVERSE_OPT.load(Ordering::Relaxed) {
        return true;
    }
    let bufferish = [
        "buf.clone",
        "bytes.clone",
        "data.clone",
        "vec.clone",
        "out.clone",
        "acc.clone",
        "builder.clone",
        "string.clone",
        "payload.clone",
        "chunk.clone",
        "buffer.clone",
        "content.clone",
        "body.clone",
        "seed.clone",
    ];
    if bufferish.iter().any(|s| code.contains(s)) {
        return true;
    }
    if code.contains("Vec") && code.contains(&clone_m) {
        return true;
    }
    let push = format!(".push{}", "(");
    if code.contains(&push) && code.contains(&clone_m) {
        return true;
    }
    false
}

fn rs003_signal(code: &str, path: &Path) -> bool {
    let println_macro = format!("println{}{}", "!", "");
    let eprintln_macro = format!("eprintln{}{}", "!", "");
    if !(code.contains(&println_macro) || code.contains(&eprintln_macro)) {
        return false;
    }
    if !ENABLE_REVERSE_OPT.load(Ordering::Relaxed) {
        return true;
    }
    let base = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
    if base.starts_with("bin_") || base.contains("example") || base.contains("demo") {
        return false;
    }
    if code.contains("cfg!(") || code.contains("debug_assertions") {
        return false;
    }
    let s = path.to_string_lossy();
    if s.contains("/counters.rs") || s.contains("AbortOnPanic") {
        return false;
    }
    true
}

fn rs004_is_format_rebind_reuse(code: &str) -> bool {
    let format_macro = format!("format{}{}", "!", "(");
    if !code.contains(&format_macro) {
        return false;
    }
    let markers = [format!("= {}", format_macro), format!("={}", format_macro)];
    for marker in &markers {
        let mut search_from = 0usize;
        while let Some(rel) = code[search_from..].find(marker.as_str()) {
            let i = search_from + rel;
            let before = &code[..i];
            if before.ends_with('=') {
                search_from = i + marker.len();
                continue;
            }
            let stmt_start = before.rfind(';').map(|j| j + 1).unwrap_or(0);
            let stmt = before[stmt_start..].trim_start();
            if stmt.starts_with("let ") {
                search_from = i + marker.len();
                continue;
            }
            let lhs = {
                let t = stmt.trim_end();
                let bytes = t.as_bytes();
                let mut s = bytes.len();
                while s > 0 && (bytes[s - 1].is_ascii_alphanumeric() || bytes[s - 1] == b'_') {
                    s -= 1;
                }
                &t[s..]
            };
            if lhs.is_empty() {
                search_from = i + marker.len();
                continue;
            }
            let after = &code[i + marker.len()..];
            let fmt_lit = extract_first_string_lit(after);
            if let Some(ref lit) = fmt_lit {
                // One-shot source lit {{{ident}}} from format!("{{{ident}}}") — usage braces.
                let mut wrap = String::with_capacity(lhs.len() + 6);
                wrap.push('{');
                wrap.push('{');
                wrap.push('{');
                wrap.push_str(lhs);
                wrap.push('}');
                wrap.push('}');
                wrap.push('}');
                if *lit == wrap {
                    search_from = i + marker.len();
                    continue;
                }
                let brace = format!("{{{lhs}}}");
                let brace_fmt = format!("{{{lhs}:");
                if lit.contains(&brace) || lit.contains(&brace_fmt) {
                    return true;
                }
                // Positional `{}/{}` with lhs in args: look past the format string literal
                if let Some(args) = args_after_first_string_lit(after) {
                    if args
                        .split(|c: char| !c.is_ascii_alphanumeric() && c != '_')
                        .any(|t| t == lhs)
                    {
                        return true;
                    }
                }
            } else if after
                .split(|c: char| !c.is_ascii_alphanumeric() && c != '_')
                .any(|t| t == lhs)
            {
                return true;
            }
            search_from = i + marker.len();
        }
    }
    false
}



fn args_after_first_string_lit(s: &str) -> Option<&str> {
    let t = s.trim_start();
    let rest = t.strip_prefix('"')?;
    let mut chars = rest.char_indices();
    while let Some((off, c)) = chars.next() {
        if c == '\\' {
            let _ = chars.next();
            continue;
        }
        if c == '"' {
            return Some(&rest[off + 1..]);
        }
    }
    None
}

fn extract_first_string_lit(s: &str) -> Option<String> {
    let t = s.trim_start();
    let rest = t.strip_prefix('"')?;
    let mut out = String::new();
    let mut chars = rest.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            out.push(c);
            if let Some(n) = chars.next() {
                out.push(n);
            }
            continue;
        }
        if c == '"' {
            return Some(out);
        }
        out.push(c);
    }
    None
}


fn rs004_signal(code: &str, path: &Path) -> bool {
    if !rs004_is_format_rebind_reuse(code) {
        return false;
    }
    if !ENABLE_REVERSE_OPT.load(Ordering::Relaxed) {
        return true;
    }
    if string_builder_path_skip(path) {
        return false;
    }
    true
}

fn rs006_signal(code: &str) -> bool {
    // collect::<Vec<_>> / collect::<Vec<T>> / collect::< Vec<
    let markers = [
        "collect::<Vec",
        "collect::< Vec",
        "collect :: <Vec",
        "collect:: <Vec",
    ];
    markers.iter().any(|m| code.contains(m))
}

fn rs_map_new_in_loop(code: &str) -> bool {
    let needle = format!("HashMap{}new", "::");
    code.contains(&needle)
}

fn rs_regex_new_in_loop(code: &str) -> bool {
    let regex_new = format!("Regex{}new", "::");
    let regex_builder = format!("RegexBuilder{}new", "::");
    code.contains(&regex_new) || code.contains(&regex_builder)
}

fn rs_file_open_in_loop(code: &str) -> bool {
    let needle = format!("File{}open", "::");
    code.contains(&needle)
}

fn rs_clock_in_loop(code: &str) -> bool {
    let needle = format!("Instant{}now", "::");
    code.contains(&needle)
}


fn ident_char(c: u8) -> bool {
    c == b'_' || c.is_ascii_alphanumeric()
}

fn ident_in(s: &str, name: &str) -> bool {
    if name.is_empty() {
        return false;
    }
    let b = s.as_bytes();
    let n = name.as_bytes();
    let mut i = 0;
    while i + n.len() <= b.len() {
        if &b[i..i + n.len()] == n {
            let before = i == 0 || !ident_char(b[i - 1]);
            let after = i + n.len() == b.len() || !ident_char(b[i + n.len()]);
            if before && after {
                return true;
            }
        }
        i += 1;
    }
    false
}

fn blank_strs(s: &str) -> String {
    let mut out = String::new();
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '"' || c == '\'' {
            let q = c;
            out.push(' ');
            while let Some(d) = chars.next() {
                if d == '\\' {
                    let _ = chars.next();
                    out.push(' ');
                    continue;
                }
                if d == q {
                    break;
                }
                out.push(' ');
            }
        } else {
            out.push(c);
        }
    }
    out
}

fn find_kw(s: &str, kw: &str) -> Option<usize> {
    let b = s.as_bytes();
    let n = kw.as_bytes();
    if n.is_empty() {
        return None;
    }
    let mut i = 0;
    while i + n.len() <= b.len() {
        if &b[i..i + n.len()] == n {
            let before = i == 0 || !ident_char(b[i - 1]);
            let after = i + n.len() == b.len() || !ident_char(b[i + n.len()]);
            if before && after {
                return Some(i);
            }
        }
        i += 1;
    }
    None
}

fn for_bind_names(code: &str) -> Vec<String> {
    let bytes = code.as_bytes();
    let mut pat = None;
    let mut i = 0;
    while i + 3 <= bytes.len() {
        if code[i..].starts_with("for") {
            let before = i == 0 || !ident_char(bytes[i - 1]);
            let after_ok = i + 3 == bytes.len() || !ident_char(bytes[i + 3]);
            if before && after_ok {
                let rest = code[i + 3..].trim_start();
                if let Some(in_at) = find_kw(rest, "in") {
                    pat = Some(&rest[..in_at]);
                }
                break;
            }
        }
        i += 1;
    }
    let Some(pat) = pat else {
        return Vec::new();
    };
    let skip = ["for", "in", "mut", "ref"];
    let pb = pat.as_bytes();
    let mut names = Vec::new();
    let mut j = 0;
    while j < pb.len() {
        if ident_char(pb[j]) && !pb[j].is_ascii_digit() {
            let start = j;
            while j < pb.len() && ident_char(pb[j]) {
                j += 1;
            }
            let name = &pat[start..j];
            if name != "_" && !skip.contains(&name) {
                names.push(name.to_string());
            }
        } else {
            j += 1;
        }
    }
    names
}

fn args_after<'a>(code: &'a str, needle: &str) -> Option<&'a str> {
    let i = code.find(needle)?;
    let rest = &code[i + needle.len()..];
    let p = rest.find('(')?;
    Some(&rest[p + 1..])
}

fn arg_uses(code: &str, needle: &str, names: &[String]) -> bool {
    if names.is_empty() {
        return false;
    }
    let Some(args) = args_after(code, needle) else {
        return false;
    };
    let blank = blank_strs(args);
    names.iter().any(|n| ident_in(&blank, n))
}

fn regex_arg_uses(code: &str, names: &[String]) -> bool {
    let n1 = format!("Regex{}new", "::");
    let n2 = format!("RegexBuilder{}new", "::");
    arg_uses(code, &n1, names) || arg_uses(code, &n2, names)
}

fn file_arg_uses(code: &str, names: &[String]) -> bool {
    let n = format!("File{}open", "::");
    arg_uses(code, &n, names)
}

pub fn scan_file(path: &Path, scope: &str) -> Vec<Finding> {
    let scope_mode = if scope == "loop" { "loop" } else { "all" };
    let Ok(text) = fs::read_to_string(path) else {
        return vec![];
    };
    if ENABLE_REVERSE_OPT.load(Ordering::Relaxed) && path_looks_testish(path) {
        return vec![];
    }
    let reverse = ENABLE_REVERSE_OPT.load(Ordering::Relaxed);
    let skip_cold = reverse && cold_cli_path_skip(path);

    let mut out = Vec::with_capacity(16);
    let mut depth = 0i32;
    let mut in_loop = 0i32;
    // Skip #[cfg(test)] / #[test] regions (inline test modules in lib files).
    let mut cfg_test_depth: Option<i32> = None;
    let mut pending_cfg_test = false;
    let mut pending_test_fn = false;
    let mut loop_names: Vec<String> = Vec::new();
    let mut clock_hold: Vec<Finding> = Vec::new();
    let mut loop_await = false;

    for (idx, raw) in text.lines().enumerate() {
        let line_no = idx + 1;
        let trimmed = raw.trim();
        if reverse {
            if trimmed.starts_with("#[cfg(test)]")
                || trimmed.starts_with("#[cfg(all(test")
                || trimmed.starts_with("#[cfg(any(test")
            {
                pending_cfg_test = true;
            }
            if trimmed.starts_with("#[test]") || trimmed.starts_with("#[tokio::test]") {
                pending_test_fn = true;
            }
        }
        let code = strip_line_comment(raw);
        let opens = code.matches('{').count() as i32;
        let closes = code.matches('}').count() as i32;
        if pending_cfg_test && opens > 0 {
            cfg_test_depth = Some(depth + 1);
            pending_cfg_test = false;
        }
        if pending_test_fn && (code.contains("fn ") || opens > 0) {
            // treat single #[test] fn as cfg-test until its body depth closes
            if cfg_test_depth.is_none() {
                cfg_test_depth = Some(depth + 1);
            }
            pending_test_fn = false;
        }
        let in_test = cfg_test_depth.is_some();

        let loop_here = is_real_loop_head(&code);
        if loop_here {
            in_loop = depth + 1;
            if code.contains(".await") || code.contains("await ") {
                loop_await = true;
            }
            loop_names.extend(for_bind_names(&code));
        }
        let match_here = scope_mode == "all" || (in_loop > 0 && depth >= in_loop);
        if match_here && !in_test {
            if rs001_signal(&code) {
                out.push(Finding {
                    rule: "rs-alloc-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG001,
                });
            }
            if rs004_signal(&code, path) {
                out.push(Finding {
                    rule: "rs-format-rebind-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG004,
                });
            }
            if rs003_signal(&code, path) {
                out.push(Finding {
                    rule: "rs-println-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG003,
                });
            }
            if code.contains(".await") {
                loop_await = true;
            }
            if rs_map_new_in_loop(&code) {
                out.push(Finding {
                    rule: "rs-map-new-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: "HashMap::new in a loop; reuse one map when the inserts stay in this loop",
                });
            }
            if rs_regex_new_in_loop(&code) && !regex_arg_uses(&code, &loop_names) {
                out.push(Finding {
                    rule: "rs-regex-new-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG007,
                });
            }
            if rs_file_open_in_loop(&code) && !file_arg_uses(&code, &loop_names) {
                out.push(Finding {
                    rule: "rs-file-open-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG008,
                });
            }
            if rs_clock_in_loop(&code) && !loop_await {
                clock_hold.push(Finding {
                    rule: "rs-clock-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG009,
                });
            }
            // rs-collect-vec-hot: collect::<Vec in loop (keep textwrap/styled_str; skip cold CLI)
            if rs006_signal(&code) && (!reverse || !skip_cold) {
                out.push(Finding {
                    rule: "rs-collect-vec-hot",
                    path: path.display().to_string(),
                    line: line_no,
                    message: MSG006,
                });
            }
        }
        depth += opens - closes;
        if depth < 0 {
            depth = 0;
        }
        if in_loop > 0 && depth < in_loop {
            if !loop_await {
                out.append(&mut clock_hold);
            } else {
                clock_hold.clear();
            }
            loop_await = false;
            loop_names.clear();
            in_loop = 0;
        }
        if let Some(td) = cfg_test_depth {
            if depth < td {
                cfg_test_depth = None;
            }
        }
    }
    if !loop_await {
        out.append(&mut clock_hold);
    }
    out
}

pub fn scan_path(root: &Path, scope: &str) -> Vec<Finding> {
    if root.is_file() {
        return if is_rs(root) {
            scan_file(root, scope)
        } else {
            vec![]
        };
    }
    let mut files: Vec<PathBuf> = Vec::with_capacity(64);
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(rd) = fs::read_dir(&dir) else {
            continue;
        };
        for ent in rd.flatten() {
            let p = ent.path();
            if p.is_dir() {
                let name = p.file_name().and_then(|s| s.to_str()).unwrap_or("");
                if skip_dir(name) {
                    continue;
                }
                stack.push(p);
            } else if is_rs(&p) {
                files.push(p);
            }
        }
    }
    let mut all = Vec::with_capacity(64);
    for f in files {
        all.extend(scan_file(&f, scope));
    }
    all
}
