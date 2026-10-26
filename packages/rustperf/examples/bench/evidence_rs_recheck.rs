use std::collections::HashMap;
use std::hint::black_box;
use std::time::Instant;

const WARM: usize = 3;
const ROUNDS: usize = 9;

fn median(xs: &mut [f64]) -> f64 {
    xs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    xs[xs.len() / 2]
}

fn time_many(name: &str, mut f: impl FnMut() -> u64) -> f64 {
    for _ in 0..WARM {
        black_box(f());
    }
    let mut samples = Vec::with_capacity(ROUNDS);
    let mut sink = 0u64;
    for _ in 0..ROUNDS {
        let t0 = Instant::now();
        sink = sink.wrapping_add(f());
        samples.push(t0.elapsed().as_secs_f64() * 1e3);
    }
    if sink == u64::MAX {
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

fn map_reused() -> u64 {
    let mut m = HashMap::with_capacity(1);
    let mut s = 0u64;
    for i in 0..20_000u64 {
        m.clear();
        m.insert(i, i);
        s = black_box(s.wrapping_add(*m.get(&i).unwrap()));
    }
    s
}

fn map_new_each() -> u64 {
    let mut s = 0u64;
    for i in 0..20_000u64 {
        let mut m = HashMap::new();
        m.insert(i, i);
        s = black_box(s.wrapping_add(*m.get(&i).unwrap()));
    }
    s
}

fn vec_with_capacity() -> u64 {
    let mut v = Vec::with_capacity(500_000);
    for i in 0..500_000u64 {
        v.push(i);
    }
    black_box(v.len() as u64)
}

fn vec_new_push() -> u64 {
    let mut v = Vec::new();
    for i in 0..500_000u64 {
        v.push(i);
    }
    black_box(v.len() as u64)
}

fn str_with_capacity() -> u64 {
    let mut s = String::with_capacity(500_000);
    for _ in 0..500_000 {
        s.push_str("x");
    }
    black_box(s.len() as u64)
}

fn str_plus() -> u64 {
    let mut s = String::new();
    for _ in 0..500_000 {
        s.push_str("x");
    }
    black_box(s.len() as u64)
}

fn pair(after_name: &str, after: impl FnMut() -> u64, before_name: &str, before: impl FnMut() -> u64) {
    let a = time_many(after_name, after);
    let b = time_many(before_name, before);
    println!("ratio_{before_name}={}", b / a);
}

fn main() {
    pair("map_reused", map_reused, "map_new_each_iter", map_new_each);
    pair("with_capacity", vec_with_capacity, "vec_new_push", vec_new_push);
    pair("plus_with_capacity", str_with_capacity, "plus_eq_loop", str_plus);
    println!("DONE_RS_RECHECK");
}
