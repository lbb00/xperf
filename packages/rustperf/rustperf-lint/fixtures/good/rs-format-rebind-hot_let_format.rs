// Fresh let-binding format! in a loop is not rs-format-rebind-hot (not rebind accum).
fn labels(n: usize) -> Vec<String> {
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let label = format!("item-{i}");
        out.push(label);
    }
    out
}
