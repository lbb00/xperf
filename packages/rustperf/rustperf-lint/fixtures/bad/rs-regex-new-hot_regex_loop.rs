fn bad(n: i32) -> usize {
    let mut hits = 0;
    for _ in 0..n {
        let re = Regex::new("a+").unwrap();
        if re.is_match("aaa") {
            hits += 1;
        }
    }
    hits
}
