fn good(chunks: &[&str]) -> usize {
    let mut n = 0usize;
    for chunk in chunks {
        n += chunk.split_whitespace().count();
    }
    n
}
