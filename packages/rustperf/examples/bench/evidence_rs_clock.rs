use std::hint::black_box;
use std::time::Instant;

const N: u64 = 100_000;
const WARM: usize = 3;
const ROUNDS: usize = 9;

fn median(xs: &mut [f64]) -> f64 {
    xs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let m = xs.len() / 2;
    if xs.len() % 2 == 1 { xs[m] } else { 0.5 * (xs[m - 1] + xs[m]) }
}

fn time_many(name: &str, mut f: impl FnMut() -> u64) -> f64 {
    for _ in 0..WARM { black_box(f()); }
    let mut samples = Vec::with_capacity(ROUNDS);
    let mut sink = 0u64;
    for _ in 0..ROUNDS {
        let t0 = Instant::now();
        sink = sink.wrapping_add(f());
        samples.push(t0.elapsed().as_secs_f64() * 1e3);
    }
    if sink == u64::MAX { std::process::exit(2); }
    let med = median(&mut samples);
    print!("{name} median_ms={med:.3} samples");
    for s in &samples { print!(" {s:.3}"); }
    println!();
    med
}

fn sample_once() -> u64 {
    let tick = black_box(Instant::now().elapsed().as_nanos() as u64);
    let mut s = 0u64;
    for _ in 0..N {
        s = black_box(s.wrapping_add(tick & 1));
    }
    s
}

fn sample_each() -> u64 {
    let mut s = 0u64;
    for _ in 0..N {
        s = s.wrapping_add(black_box(Instant::now()).elapsed().as_nanos() as u64 & 1);
    }
    s
}

fn main() {
    let after = time_many("sample_once", sample_once);
    let before = time_many("sample_each_iter", sample_each);
    println!("rustc_ratio={}", before / after);
    println!("DONE_RS_CLOCK");
}
