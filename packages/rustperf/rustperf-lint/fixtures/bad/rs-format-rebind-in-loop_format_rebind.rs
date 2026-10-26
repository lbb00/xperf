fn bad(n: usize) -> String {
    let mut s = String::new();
    for i in 0..n {
        s = format!("{s}{i}");
    }
    s
}
