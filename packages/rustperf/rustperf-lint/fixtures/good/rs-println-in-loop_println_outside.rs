fn good(n: usize) -> usize {
    let mut s = 0usize;
    for i in 0..n {
        s += i;
    }
    println!("{s}");
    s
}
