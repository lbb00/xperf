fn good(items: &[u32]) -> Vec<u32> {
    let mut out = Vec::with_capacity(items.len());
    for x in items.iter() {
        out.push(*x);
    }
    out
}
