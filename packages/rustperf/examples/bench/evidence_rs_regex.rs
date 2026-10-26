use regex::Regex;
use std::hint::black_box;
use std::time::Instant;

const N: usize = 2000;
const WARM: usize = 3;
const ROUNDS: usize = 9;
const PAT: &str = r"([A-Za-z]+)-([0-9]{2,4})";
const TEXT: &str = "id-2026";

fn median(xs: &mut [f64]) -> f64 {
    xs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let m = xs.len() / 2;
    if xs.len() % 2 == 1 {
        xs[m]
    } else {
        0.5 * (xs[m - 1] + xs[m])
    }
}

fn time_many(name: &str, mut f: impl FnMut() -> u32) -> f64 {
    for _ in 0..WARM {
        black_box(f());
    }
    let mut samples = Vec::with_capacity(ROUNDS);
    let mut sink = 0u32;
    for _ in 0..ROUNDS {
        let t0 = Instant::now();
        sink = sink.wrapping_add(f());
        samples.push(t0.elapsed().as_secs_f64() * 1e3);
    }
    if sink == u32::MAX {
        std::process::exit(2);
    }
    let med = median(&mut samples);
    print!("{name} median_ms={med:.6} samples");
    for s in &samples {
        print!(" {s:.3}");
    }
    println!();
    med
}

fn regex_once() -> u32 {
    let re = Regex::new(PAT).unwrap();
    let mut s = 0u32;
    for _ in 0..N {
        s = black_box(s.wrapping_add(u32::from(re.is_match(TEXT))));
    }
    s
}

fn regex_each() -> u32 {
    let mut s = 0u32;
    for _ in 0..N {
        let re = Regex::new(PAT).unwrap();
        s = black_box(s.wrapping_add(u32::from(re.is_match(TEXT))));
    }
    s
}

fn main() {
    let after = time_many("regex_once", regex_once);
    let before = time_many("regex_new_each_iter", regex_each);
    println!("rustc_ratio={}", before / after);
    println!("DONE_RS_REGEX");
}
