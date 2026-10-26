//! Evidence microbench for rs-string-plus-in-loop → packages/rustperf/evidence/rs-string-plus-in-loop.jsonl
//! Smell: String += / push_str / format! in loop; fix: with_capacity + push_str / write!.
//! Build: rustc -C opt-level=3 evidence_rs002.rs -o out/evidence_rs002
//! Timer: std::time::Instant (wall); warm=3; median of 9.

use std::env;
use std::fmt::Write as _;
use std::fs;
use std::hint::black_box;
use std::path::PathBuf;
use std::time::Instant;

const WARM: usize = 3;
const ROUNDS: usize = 9;

fn median(xs: &mut [f64]) -> f64 {
    xs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = xs.len();
    if n == 0 {
        return 0.0;
    }
    if n % 2 == 1 {
        xs[n / 2]
    } else {
        0.5 * (xs[n / 2 - 1] + xs[n / 2])
    }
}

fn time_many<F: FnMut() -> usize>(mut f: F) -> f64 {
    for _ in 0..WARM {
        black_box(f());
    }
    let mut samples = [0.0f64; ROUNDS];
    for r in 0..ROUNDS {
        let t0 = Instant::now();
        black_box(f());
        samples[r] = t0.elapsed().as_secs_f64() * 1e3;
    }
    median(&mut samples)
}

fn env_usize(key: &str, default: usize) -> usize {
    env::var(key)
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(default)
}

fn rustc_version() -> String {
    if let Ok(v) = env::var("RS002_RUSTC") {
        return v;
    }
    let out = std::process::Command::new("rustc")
        .arg("--version")
        .output()
        .ok();
    if let Some(o) = out {
        let s = String::from_utf8_lossy(&o.stdout);
        if let Some(rest) = s.strip_prefix("rustc ") {
            return rest.split_whitespace().next().unwrap_or("unknown").to_string();
        }
    }
    "unknown".to_string()
}

fn utc_ts() -> String {
    if let Ok(ts) = env::var("EVIDENCE_TS") {
        return ts;
    }
    std::process::Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "1970-01-01T00:00:00Z".to_string())
}

fn main() {
    // Defaults sized so Instant medians are above timer noise on this machine.
    let n_plus = env_usize("RS002_N_PLUS", 500_000);
    let n_chunk = env_usize("RS002_N_CHUNK", 100_000);
    let n_fmt = env_usize("RS002_N_FMT", 20_000);
    let n_small = env_usize("RS002_N_SMALL", 100);
    let small_reps = env_usize("RS002_SMALL_REPS", 20_000);
    let chunk = "x".repeat(32);
    let rustc = rustc_version();
    let opt = env::var("RS002_OPT").unwrap_or_else(|_| "opt-level=3".to_string());
    let ts = utc_ts();

    eprintln!(
        "rs-string-plus-in-loop evidence: rustc {rustc} {opt} warm={WARM} rounds={ROUNDS} \
         N_plus={n_plus} N_chunk={n_chunk} N_fmt={n_fmt} N_small={n_small} \
         small_reps={small_reps}"
    );

    let mut lines: Vec<String> = Vec::new();
    let mut emit = |case: &str, role: &str, med: f64, ops: usize, ratio: f64| {
        let obj = format!(
            "{{\"rule\":\"rs-string-plus-in-loop\",\"case\":\"{case}\",\"role\":\"{role}\",\"rustc\":\"{rustc}\",\"opt\":\"{opt}\",\"median_ms\":{med:.6},\"ops\":{ops},\"ratio\":{ratio:.6},\"ts\":\"{ts}\"}}"
        );
        eprintln!("  {role} {case} median={med:.3} ms ops={ops} ratio={ratio:.3}");
        lines.push(obj);
    };

    // Pair A — fixture-shaped: s += "x" vs with_capacity + push_str
    eprintln!("-- pair A fixture += \"x\"");
    let med_aa = time_many(|| {
        let mut s = String::with_capacity(n_plus);
        for _ in 0..n_plus {
            s.push_str("x");
        }
        s.len()
    });
    let med_ab = time_many(|| {
        let mut s = String::new();
        for _ in 0..n_plus {
            s += "x";
        }
        s.len()
    });
    emit("plus_with_capacity", "after", med_aa, n_plus, 1.0);
    emit(
        "plus_eq_loop",
        "before",
        med_ab,
        n_plus,
        med_ab / med_aa.max(1e-12),
    );

    // Pair B — fixed 32-byte push_str without capacity vs with_capacity
    eprintln!("-- pair B chunk32 push_str");
    let med_ba = time_many(|| {
        let mut s = String::with_capacity(n_chunk * 32);
        for _ in 0..n_chunk {
            s.push_str(&chunk);
        }
        s.len()
    });
    let med_bb = time_many(|| {
        let mut s = String::new();
        for _ in 0..n_chunk {
            s.push_str(&chunk);
        }
        s.len()
    });
    emit("chunk32_with_capacity", "after", med_ba, n_chunk, 1.0);
    emit(
        "chunk32_push_str_loop",
        "before",
        med_bb,
        n_chunk,
        med_bb / med_ba.max(1e-12),
    );

    // Pair C — format! accumulation vs with_capacity + write! (good fixture intent)
    eprintln!("-- pair C format! accum vs write!");
    let med_ca = time_many(|| {
        let mut s = String::with_capacity(n_fmt * 6);
        for i in 0..n_fmt {
            let _ = write!(s, "{i}");
        }
        s.len()
    });
    let med_cb = time_many(|| {
        let mut s = String::new();
        for i in 0..n_fmt {
            s = format!("{s}{i}");
        }
        s.len()
    });
    emit("digits_write", "after", med_ca, n_fmt, 1.0);
    emit(
        "digits_format_accum",
        "before",
        med_cb,
        n_fmt,
        med_cb / med_ca.max(1e-12),
    );

    // Pair D — small builders repeated (oneshot-ish N; expect ~1× on +=)
    // ops = n_small (chars per builder); small_reps is measurement outer only.
    eprintln!("-- pair D small N (×{small_reps} reps for timer)");
    let med_da = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..small_reps {
            let mut s = String::with_capacity(n_small);
            for _ in 0..n_small {
                s.push_str("x");
            }
            sink = sink.wrapping_add(s.len());
        }
        sink
    });
    let med_db = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..small_reps {
            let mut s = String::new();
            for _ in 0..n_small {
                s += "x";
            }
            sink = sink.wrapping_add(s.len());
        }
        sink
    });
    emit("small_n_with_capacity", "after", med_da, n_small, 1.0);
    emit(
        "small_n_plus_eq",
        "before",
        med_db,
        n_small,
        med_db / med_da.max(1e-12),
    );

    let out_dir = env::var("EVIDENCE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("../../evidence"));
    fs::create_dir_all(&out_dir).ok();
    let out_path = out_dir.join("rs-string-plus-in-loop.jsonl");
    let body = lines.join("\n") + "\n";
    fs::write(&out_path, &body).expect("write jsonl");
    eprintln!("wrote {}", out_path.display());
    print!("{body}");
}
