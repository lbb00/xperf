use std::fmt::Write;
pub fn join(parts: &[&str]) -> String {
    let mut s = String::with_capacity(64);
    for (i, p) in parts.iter().enumerate() {
        if i > 0 {
            s.push_str(", "); // tiny separator — must not fire rs-string-plus-in-loop
        }
        let _ = write!(s, "{p}");
    }
    s
}
