func good(paths: [String]) -> Int {
    var s = 0
    for path in paths {
        let data = try? String(contentsOfFile: path)
        s = data?.count ?? 0
    }
    return s
}
