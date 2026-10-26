fn good(paths: &[&str]) {
    for path in paths {
        let _f = std::fs::File::open(path);
    }
}
