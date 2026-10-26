fn good(lines: &[&str]) -> usize {
    let re = Regex::new("a+").unwrap();
    let mut n = 0;
    for line in lines {
        if re.is_match(line) {
            n += 1;
        }
    }
    n
}
