//! Evidence microbench for rs-alloc-in-loop → packages/rustperf/evidence/rs-alloc-in-loop.jsonl
//! Smell: alloc/clone in loop (Vec::new / .clone / to_string / to_owned).
//! Build: rustc -C opt-level=3 evidence_rs001.rs -o out/evidence_rs001
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
    if let Ok(v) = env::var("RS001_RUSTC") {
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
    let outer_a = env_usize("RS001_OUTER_A", 50_000);
    let inner_a = env_usize("RS001_INNER_A", 64);
    let n_clone = env_usize("RS001_N_CLONE", 200_000);
    let seed_len = env_usize("RS001_SEED_LEN", 64);
    let n_grow = env_usize("RS001_N_GROW", 8_000);
    let n_to_string = env_usize("RS001_N_TO_STRING", 200_000);
    let outer_small = env_usize("RS001_OUTER_SMALL", 100);
    let inner_small = env_usize("RS001_INNER_SMALL", 16);
    let small_reps = env_usize("RS001_SMALL_REPS", 20_000);

    let rustc = rustc_version();
    let opt = env::var("RS001_OPT").unwrap_or_else(|_| "opt-level=3".to_string());
    let ts = utc_ts();

    eprintln!(
        "rs-alloc-in-loop evidence: rustc {rustc} {opt} warm={WARM} rounds={ROUNDS} \
         outer_a={outer_a} inner_a={inner_a} n_clone={n_clone} seed_len={seed_len} \
         n_grow={n_grow} n_to_string={n_to_string} outer_small={outer_small} \
         inner_small={inner_small} small_reps={small_reps}"
    );

    let mut lines: Vec<String> = Vec::new();
    let mut emit = |case: &str, role: &str, med: f64, ops: usize, ratio: f64| {
        let obj = format!(
            "{{\"rule\":\"rs-alloc-in-loop\",\"case\":\"{case}\",\"role\":\"{role}\",\"rustc\":\"{rustc}\",\"opt\":\"{opt}\",\"median_ms\":{med:.6},\"ops\":{ops},\"ratio\":{ratio:.6},\"ts\":\"{ts}\"}}"
        );
        eprintln!("  {role} {case} median={med:.3} ms ops={ops} ratio={ratio:.3}");
        lines.push(obj);
    };

    // Pair A — Vec::new each outer iter vs clear/reuse with_capacity
    eprintln!("-- pair A Vec::new each iter vs clear/reuse");
    let med_ab = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..outer_a {
            let mut v = Vec::new();
            for j in 0..inner_a {
                v.push(j as u32);
            }
            sink = sink.wrapping_add(v.len());
        }
        sink
    });
    let med_aa = time_many(|| {
        let mut sink = 0usize;
        let mut v = Vec::with_capacity(inner_a);
        for _ in 0..outer_a {
            v.clear();
            for j in 0..inner_a {
                v.push(j as u32);
            }
            sink = sink.wrapping_add(v.len());
        }
        sink
    });
    emit("vec_clear_reuse", "after", med_aa, outer_a, 1.0);
    emit(
        "vec_new_each_iter",
        "before",
        med_ab,
        outer_a,
        med_ab / med_aa.max(1e-12),
    );

    // Pair B — fixture-shaped seed.clone() into Vec::new vs with_capacity
    // (capacity only; clone cost dominates — expect ~1×)
    eprintln!("-- pair B fixture seed.clone() vs with_capacity");
    let seed = "x".repeat(seed_len);
    // Run before first this time to reduce order bias from prior pair.
    let med_bb = time_many(|| {
        let mut out = Vec::new();
        for _ in 0..n_clone {
            out.push(seed.clone());
        }
        out.len()
    });
    let med_ba = time_many(|| {
        let mut out = Vec::with_capacity(n_clone);
        for _ in 0..n_clone {
            out.push(seed.clone());
        }
        out.len()
    });
    emit("clone_with_capacity", "after", med_ba, n_clone, 1.0);
    emit(
        "clone_vec_new",
        "before",
        med_bb,
        n_clone,
        med_bb / med_ba.max(1e-12),
    );

    // Pair C — growing String .clone() each step vs clear+push_str into reused buf
    // (both copy bytes; reuse avoids a fresh heap String alloc per step)
    eprintln!("-- pair C growing clone vs clear+push_str reuse");
    let med_cb = time_many(|| {
        let mut sink = 0usize;
        let mut acc = String::new();
        for _ in 0..n_grow {
            acc.push('x');
            let c = acc.clone();
            sink = sink.wrapping_add(c.len());
        }
        sink
    });
    let med_ca = time_many(|| {
        let mut sink = 0usize;
        let mut acc = String::with_capacity(n_grow);
        let mut buf = String::with_capacity(n_grow);
        for _ in 0..n_grow {
            acc.push('x');
            buf.clear();
            buf.push_str(&acc);
            sink = sink.wrapping_add(buf.len());
        }
        sink
    });
    emit("grow_clear_push_str", "after", med_ca, n_grow, 1.0);
    emit(
        "grow_clone_each",
        "before",
        med_cb,
        n_grow,
        med_cb / med_ca.max(1e-12),
    );

    // Pair D — i.to_string() each iter vs clear + write! into reused String
    eprintln!("-- pair D to_string vs clear+write!");
    let med_db = time_many(|| {
        let mut sink = 0usize;
        for i in 0..n_to_string {
            let s = i.to_string();
            sink = sink.wrapping_add(s.len());
        }
        sink
    });
    let med_da = time_many(|| {
        let mut sink = 0usize;
        let mut s = String::with_capacity(24);
        for i in 0..n_to_string {
            s.clear();
            let _ = write!(s, "{i}");
            sink = sink.wrapping_add(s.len());
        }
        sink
    });
    emit("to_string_clear_write", "after", med_da, n_to_string, 1.0);
    emit(
        "to_string_each_iter",
        "before",
        med_db,
        n_to_string,
        med_db / med_da.max(1e-12),
    );

    // Pair E — small N of Pair A (×reps for timer)
    eprintln!("-- pair E small N Vec::new (×{small_reps} reps)");
    let med_eb = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..small_reps {
            for _ in 0..outer_small {
                let mut v = Vec::new();
                for j in 0..inner_small {
                    v.push(j as u32);
                }
                sink = sink.wrapping_add(v.len());
            }
        }
        sink
    });
    let med_ea = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..small_reps {
            let mut v = Vec::with_capacity(inner_small);
            for _ in 0..outer_small {
                v.clear();
                for j in 0..inner_small {
                    v.push(j as u32);
                }
                sink = sink.wrapping_add(v.len());
            }
        }
        sink
    });
    emit("small_n_vec_clear_reuse", "after", med_ea, outer_small, 1.0);
    emit(
        "small_n_vec_new_each",
        "before",
        med_eb,
        outer_small,
        med_eb / med_ea.max(1e-12),
    );

    let out_dir = env::var("EVIDENCE_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("../../evidence"));
    fs::create_dir_all(&out_dir).ok();
    let out_path = out_dir.join("rs-alloc-in-loop.jsonl");
    let body = lines.join("\n") + "\n";
    fs::write(&out_path, &body).expect("write jsonl");
    eprintln!("wrote {}", out_path.display());
    print!("{body}");
}
