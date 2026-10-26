use std::fs::{self, File};
use std::hint::black_box;
use std::io::Read;
use std::time::Instant;

const N: usize = 2000;
const WARM: usize = 3;
const ROUNDS: usize = 9;

fn median(xs: &mut [f64]) -> f64 {
    xs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let m = xs.len() / 2;
    if xs.len() % 2 == 1 { xs[m] } else { 0.5 * (xs[m - 1] + xs[m]) }
}

fn time_many(name: &str, mut f: impl FnMut() -> i32) -> f64 {
    for _ in 0..WARM { black_box(f()); }
    let mut samples = Vec::with_capacity(ROUNDS);
    let mut sink = 0i32;
    for _ in 0..ROUNDS {
        let t0 = Instant::now();
        sink = sink.wrapping_add(f());
        samples.push(t0.elapsed().as_secs_f64() * 1e3);
    }
    if sink == i32::MAX { std::process::exit(2); }
    let med = median(&mut samples);
    print!("{name} median_ms={med:.6} samples");
    for s in &samples { print!(" {s:.3}"); }
    println!();
    med
}

fn path() -> String {
    let p = std::env::temp_dir().join("xperf-one-byte");
    fs::write(&p, b"x").unwrap();
    p.to_string_lossy().into_owned()
}

fn open_once(path: &str) -> i32 {
    let mut f = File::open(path).unwrap();
    let mut buf = [0u8; 1];
    f.read_exact(&mut buf).unwrap();
    let mut s = 0i32;
    for _ in 0..N {
        s = black_box(s.wrapping_add(buf[0] as i32));
    }
    s
}

fn open_each(path: &str) -> i32 {
    let mut s = 0i32;
    for _ in 0..N {
        let mut f = File::open(path).unwrap();
        let mut buf = [0u8; 1];
        f.read_exact(&mut buf).unwrap();
        s = s.wrapping_add(buf[0] as i32);
    }
    s
}

fn main() {
    let path = path();
    let after = time_many("open_once", || open_once(&path));
    let before = time_many("open_each_iter", || open_each(&path));
    println!("rustc_ratio={}", before / after);
    println!("DONE_RS_FILE");
}
