fn bad(n: i32) {
    for _ in 0..n {
        let _f = std::fs::File::open("one.txt");
    }
}
