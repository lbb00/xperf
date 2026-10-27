fn good(keys: &[u32]) {
    let mut m = HashMap::with_capacity(keys.len());
    for key in keys {
        m.insert(*key, 1);
    }
}
