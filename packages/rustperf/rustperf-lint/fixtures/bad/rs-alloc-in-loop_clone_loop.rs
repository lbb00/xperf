fn bad(n: usize) -> Vec<String> {
    let seed = String::from("x");
    let mut out = Vec::new();
    for _ in 0..n {
        out.push(seed.clone());
    }
    out
}
