fn bad(items: &[u32]) -> Vec<u32> {
    let mut out = Vec::new();
    for x in items.iter() {
        out.push(*x);
    }
    out
}
