use std::fmt::Write;

fn join_parts(parts: &[&str]) -> String {
    let mut s = String::with_capacity(parts.iter().map(|p| p.len()).sum());
    for p in parts {
        let _ = write!(s, "{p}");
    }
    s
}

fn main() {
    println!("{}", join_parts(&["a", "b", "c"]));
}
