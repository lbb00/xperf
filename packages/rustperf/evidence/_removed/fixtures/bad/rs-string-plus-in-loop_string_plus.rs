fn bad(n: usize) -> String {
    let mut s = String::new();
    for i in 0..n {
        s += "x";
        let _ = i;
    }
    s
}
