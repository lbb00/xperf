fn bad(chunks: &[&str]) -> usize {
    let mut n = 0usize;
    for chunk in chunks {
        let words = chunk.split_whitespace().collect::<Vec<_>>();
        n += words.len();
    }
    n
}
