fn wrap_usage(mut sc_names: String, flag: bool) -> String {
    // one-shot brace wrap — not format! accum
    for _ in 0..1 {
        if flag {
            sc_names = format!("{{{sc_names}}}");
        }
    }
    sc_names
}
