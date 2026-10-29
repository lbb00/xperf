fn good(lines: &[&str]) -> usize {
    let mut n = 0;
    for line in lines {
        let re = Regex::new(line).unwrap();
        if re.is_match(line) {
            n += 1;
        }
    }
    n
}
