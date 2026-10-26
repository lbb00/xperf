// to_owned outside a real loop (match arm) must stay clean.
pub fn label(v: Option<&str>) -> String {
    match v {
        Some(s) => s.to_owned(),
        None => "...".to_owned(),
    }
}
