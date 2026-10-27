mod scan;

use scan::{scan_path, Finding, ENABLE_REVERSE_OPT};
use std::collections::HashMap;
use std::env;
use std::path::PathBuf;
use std::process;

#[derive(Clone, Copy, PartialEq)]
enum Sev {
    Off,
    Hint,
    Error,
}

fn parse_sev(s: &str) -> Option<Sev> {
    match s {
        "error" => Some(Sev::Error),
        "hint" => Some(Sev::Hint),
        "off" => Some(Sev::Off),
        _ => None,
    }
}

fn sev_name(s: Sev) -> &'static str {
    match s {
        Sev::Error => "error",
        Sev::Hint => "hint",
        Sev::Off => "off",
    }
}

fn usage(code: i32) -> ! {
    eprintln!(
        "Usage: rustperf-lint PATH... [options]\n  --format text|json\n  --severity RULE=error|hint|off\n  --scope all|loop   (default: all)\n  --strict-hints\n  --no-fail\n  --raw-paths          include test/bench/examples (baseline dumps)"
    );
    process::exit(code);
}

fn default_sev() -> HashMap<&'static str, Sev> {
    HashMap::from([
        ("rs-alloc-hot", Sev::Off),
        ("rs-println-hot", Sev::Hint),
        ("rs-format-rebind-hot", Sev::Error),
        ("rs-collect-vec-hot", Sev::Hint),
        ("rs-map-new-hot", Sev::Hint),
        ("rs-regex-new-hot", Sev::Hint),
        ("rs-file-open-hot", Sev::Hint),
        ("rs-clock-hot", Sev::Hint),
    ])
}

fn apply_sev(rs: &mut HashMap<&'static str, Sev>, spec: &str) -> bool {
    let Some((rule, level)) = spec.split_once('=') else {
        return false;
    };
    let Some(sev) = parse_sev(level) else {
        return false;
    };
    // leak rule key into static map of known rules only
    let key = match rule {
        "rs-alloc-hot" => "rs-alloc-hot",
        "rs-println-hot" => "rs-println-hot",
        "rs-format-rebind-hot" => "rs-format-rebind-hot",
        "rs-collect-vec-hot" => "rs-collect-vec-hot",
        "rs-map-new-hot" => "rs-map-new-hot",
        "rs-regex-new-hot" => "rs-regex-new-hot",
        "rs-file-open-hot" => "rs-file-open-hot",
        "rs-clock-hot" => "rs-clock-hot",
        _ => return false,
    };
    rs.insert(key, sev);
    true
}

fn emit(findings: &[Finding], rs: &HashMap<&'static str, Sev>, format: &str) -> (usize, usize) {
    let mut nerr = 0usize;
    let mut nhint = 0usize;
    let mut text_rows: Vec<String> = Vec::with_capacity(findings.len());
    let mut json_rows: Vec<String> = Vec::with_capacity(findings.len());
    for f in findings {
        let s = *rs.get(f.rule).unwrap_or(&Sev::Hint);
        if s == Sev::Off {
            continue;
        }
        if s == Sev::Error {
            nerr += 1;
        } else {
            nhint += 1;
        }
        if format == "json" {
            json_rows.push(format!(
                "{{\"rule\":\"{}\",\"severity\":\"{}\",\"path\":\"{}\",\"line\":{},\"message\":\"{}\"}}",
                f.rule,
                sev_name(s),
                f.path,
                f.line,
                f.message
            ));
        } else {
            text_rows.push(format!(
                "{}:{}: {} {}: {}",
                f.path,
                f.line,
                sev_name(s),
                f.rule,
                f.message
            ));
        }
    }
    if format == "json" {
        println!("[{}]", json_rows.join(","));
    } else {
        if !text_rows.is_empty() {
            println!("{}", text_rows.join("\n"));
        }
        let shown = nerr + nhint;
        if shown > 0 {
            eprintln!("{shown} finding(s) ({nerr} error, {nhint} hint)");
        } else {
            eprintln!("ok");
        }
    }
    (nerr, nhint)
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        usage(2);
    }
    let mut rs = default_sev();
    let mut format = "text".to_string();
    let mut strict_hints = false;
    let mut scope = String::from("all");
    let mut no_fail = false;
    let mut paths: Vec<PathBuf> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        if a == "-h" || a == "--help" {
            usage(0);
        } else if a == "--format" {
            i += 1;
            if i >= args.len() {
                usage(2);
            }
            format = args[i].clone();
        } else if let Some(rest) = a.strip_prefix("--format=") {
            format = rest.to_string();
        } else if a == "--severity" {
            i += 1;
            if i >= args.len() || !apply_sev(&mut rs, &args[i]) {
                usage(2);
            }
        } else if let Some(rest) = a.strip_prefix("--severity=") {
            if !apply_sev(&mut rs, rest) {
                usage(2);
            }
        } else if a == "--strict-hints" {
            strict_hints = true;
        } else if a == "--no-fail" {
            no_fail = true;
        } else if a == "--scope" {
            i += 1;
            if i >= args.len() {
                usage(2);
            }
            scope = args[i].clone();
            if scope != "all" && scope != "loop" {
                usage(2);
            }
        } else if let Some(rest) = a.strip_prefix("--scope=") {
            scope = rest.to_string();
            if scope != "all" && scope != "loop" {
                usage(2);
            }
        } else if a == "--raw-paths" {
            ENABLE_REVERSE_OPT.store(false, std::sync::atomic::Ordering::Relaxed);
        } else if a.starts_with('-') {
            usage(2);
        } else {
            paths.push(PathBuf::from(a));
        }
        i += 1;
    }
    if paths.is_empty() {
        usage(2);
    }
    let mut findings: Vec<Finding> = Vec::with_capacity(64);
    for p in &paths {
        findings.extend(scan_path(p, &scope));
    }
    let (nerr, nhint) = emit(&findings, &rs, &format);
    if no_fail {
        return;
    }
    if nerr > 0 || (strict_hints && nhint > 0) {
        process::exit(1);
    }
}
