func good(path: String, n: Int) -> Int {
    let data = try? String(contentsOfFile: path)
    var s = 0
    for _ in 0..<n {
        s = data?.count ?? 0
    }
    return s
}
