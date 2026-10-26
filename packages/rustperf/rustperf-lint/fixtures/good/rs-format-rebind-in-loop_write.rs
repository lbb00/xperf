use std::fmt::Write;

fn good(n: usize) -> String {
    let mut s = String::with_capacity(n * 2);
    for i in 0..n {
        let _ = write!(s, "{i}");
    }
    s
}
