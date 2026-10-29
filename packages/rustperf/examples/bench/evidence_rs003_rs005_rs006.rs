//! Evidence for rs-println-hot / rs-vec-no-capacity / rs-collect-vec-hot
//! rustc -C opt-level=3 evidence_rs003_rs005_rs006.rs -o /tmp/evidence_rs_rest && /tmp/evidence_rs_rest

use std::env;
use std::fs;
use std::hint::black_box;
use std::io::{self, Write};
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
    std::process::Command::new("rustc")
        .arg("--version")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|s| {
            s.strip_prefix("rustc ")
                .map(|rest| rest.split_whitespace().next().unwrap_or("unknown").to_string())
        })
        .unwrap_or_else(|| "unknown".to_string())
}

fn utc_ts() -> String {
    std::process::Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "1970-01-01T00:00:00Z".to_string())
}

fn main() {
    let out_dir = env::var("EVIDENCE_DIR").unwrap_or_else(|_| {
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()))
            .join("../../evidence")
            .to_string_lossy()
            .into()
    });
    // Prefer script-relative when run from examples/bench
    let out_dir = if env::var("EVIDENCE_DIR").is_ok() {
        out_dir
    } else {
        let mut p = PathBuf::from(env::current_dir().unwrap());
        // if cwd is examples/bench
        if p.ends_with("bench") {
            p.pop();
            p.pop();
            p.push("evidence");
            p.to_string_lossy().into()
        } else {
            match env::var("XPERF_ROOT") {
                Ok(root) => format!("{}/packages/rustperf/evidence", root),
                Err(_) => "../../evidence".into(),
            }
        }
    };
    fs::create_dir_all(&out_dir).ok();
    let rustc = rustc_version();
    let opt = "opt-level=3".to_string();
    let ts = utc_ts();
    let mut lines: Vec<(String, String)> = Vec::new();

    let mut emit = |rule: &str, case: &str, role: &str, med: f64, ops: usize, ratio: f64| {
        let obj = format!(
            "{{\"rule\":\"{rule}\",\"case\":\"{case}\",\"role\":\"{role}\",\"rustc\":\"{rustc}\",\"opt\":\"{opt}\",\"median_ms\":{med:.6},\"ops\":{ops},\"ratio\":{ratio:.6},\"ts\":\"{ts}\"}}"
        );
        eprintln!("  {rule} {role} {case} median={med:.3} ms ops={ops} ratio={ratio:.3}");
        lines.push((rule.to_string(), obj));
    };

    // rs-println-hot: println in loop vs quiet (stdout discarded)
    let n3 = env_usize("RS003_N", 20000);
    eprintln!("rs-println-hot println-loop n={n3}");
    let med3a = time_many(|| {
        let mut s = 0usize;
        for i in 0..n3 {
            s = s.wrapping_add(i);
        }
        black_box(s)
    });
    let med3b = {
        // redirect stdout to /dev/null for the println case
        use std::fs::OpenOptions;
        let null = OpenOptions::new().write(true).open("/dev/null").unwrap();
        // We can't easily redirect println of child; use writeln! to null sink as "after"
        // and measure writeln to null in loop as before vs single write
        let med_after = time_many(|| {
            let mut null = OpenOptions::new().write(true).open("/dev/null").unwrap();
            let mut buf = String::with_capacity(n3 * 8);
            for i in 0..n3 {
                use std::fmt::Write as _;
                let _ = writeln!(buf, "{i}");
            }
            null.write_all(buf.as_bytes()).ok();
            n3
        });
        let med_before = time_many(|| {
            let mut null = OpenOptions::new().write(true).open("/dev/null").unwrap();
            for i in 0..n3 {
                let _ = writeln!(null, "{i}");
            }
            n3
        });
        emit("rs-println-hot", "buffer_then_write", "after", med_after, n3, 1.0);
        emit(
            "rs-println-hot",
            "writeln_each_iter",
            "before",
            med_before,
            n3,
            med_before / med_after.max(1e-9),
        );
        // also quiet compute baseline vs writeln each (I/O cost)
        emit("rs-println-hot", "quiet_compute", "after", med3a, n3, 1.0);
        emit(
            "rs-println-hot",
            "writeln_vs_quiet",
            "before",
            med_before,
            n3,
            med_before / med3a.max(1e-9),
        );
        let _ = null;
        med_before
    };
    let _ = med3b;

    // rs-vec-no-capacity: Vec::new + push vs with_capacity
    let n5 = env_usize("RS005_N", 500_000);
    let items: Vec<u32> = (0..n5 as u32).collect();
    eprintln!("rs-vec-no-capacity vec_new_push n={n5}");
    let med5a = time_many(|| {
        let mut out = Vec::with_capacity(items.len());
        for x in items.iter() {
            out.push(*x);
        }
        out.len()
    });
    let med5b = time_many(|| {
        let mut out = Vec::new();
        for x in items.iter() {
            out.push(*x);
        }
        out.len()
    });
    emit("rs-vec-no-capacity", "with_capacity", "after", med5a, n5, 1.0);
    emit(
        "rs-vec-no-capacity",
        "vec_new_push",
        "before",
        med5b,
        n5,
        med5b / med5a.max(1e-9),
    );

    let n5s = env_usize("RS005_N_SMALL", 100);
    let items_s = &items[..n5s];
    let reps = env_usize("RS005_SMALL_REPS", 10000);
    let med5sa = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..reps {
            let mut out = Vec::with_capacity(items_s.len());
            for x in items_s.iter() {
                out.push(*x);
            }
            sink = sink.wrapping_add(out.len());
        }
        sink
    });
    let med5sb = time_many(|| {
        let mut sink = 0usize;
        for _ in 0..reps {
            let mut out = Vec::new();
            for x in items_s.iter() {
                out.push(*x);
            }
            sink = sink.wrapping_add(out.len());
        }
        sink
    });
    emit("rs-vec-no-capacity", "small_with_capacity", "after", med5sa, n5s, 1.0);
    emit(
        "rs-vec-no-capacity",
        "small_vec_new_push",
        "before",
        med5sb,
        n5s,
        med5sb / med5sa.max(1e-9),
    );

    // rs-collect-vec-hot: collect in loop vs count
    let n6 = env_usize("RS006_CHUNKS", 5000);
    let chunk = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod";
    let chunks: Vec<&str> = vec![chunk; n6];
    eprintln!("rs-collect-vec-hot collect-in-loop chunks={n6}");
    let med6a = time_many(|| {
        let mut n = 0usize;
        for c in &chunks {
            n += c.split_whitespace().count();
        }
        n
    });
    let med6b = time_many(|| {
        let mut n = 0usize;
        for c in &chunks {
            let words = c.split_whitespace().collect::<Vec<_>>();
            n += words.len();
        }
        n
    });
    emit("rs-collect-vec-hot", "count_no_collect", "after", med6a, n6, 1.0);
    emit(
        "rs-collect-vec-hot",
        "collect_in_loop",
        "before",
        med6b,
        n6,
        med6b / med6a.max(1e-9),
    );

    let n6s = env_usize("RS006_CHUNKS_SMALL", 50);
    let chunks_s = &chunks[..n6s];
    let reps6 = env_usize("RS006_SMALL_REPS", 2000);
    let med6sa = time_many(|| {
        let mut n = 0usize;
        for _ in 0..reps6 {
            for c in chunks_s {
                n += c.split_whitespace().count();
            }
        }
        n
    });
    let med6sb = time_many(|| {
        let mut n = 0usize;
        for _ in 0..reps6 {
            for c in chunks_s {
                let words = c.split_whitespace().collect::<Vec<_>>();
                n += words.len();
            }
        }
        n
    });
    emit("rs-collect-vec-hot", "small_count", "after", med6sa, n6s, 1.0);
    emit(
        "rs-collect-vec-hot",
        "small_collect",
        "before",
        med6sb,
        n6s,
        med6sb / med6sa.max(1e-9),
    );

    for rule in ["rs-println-hot", "rs-vec-no-capacity", "rs-collect-vec-hot"] {
        let path = format!("{out_dir}/{rule}.jsonl");
        let body: String = lines
            .iter()
            .filter(|(r, _)| r == rule)
            .map(|(_, o)| o.as_str())
            .collect::<Vec<_>>()
            .join("\n")
            + "\n";
        fs::write(&path, &body).expect("write");
        eprintln!("wrote {path}");
        print!("{body}");
    }
    let _ = io::stdout();
}
