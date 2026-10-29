fn bad(keys: &[u32]) {
    for key in keys {
        let mut m = HashMap::new();
        m.insert(*key, 1);
    }
}
