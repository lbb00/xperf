func bad(path: String, n: Int) -> Int {
    var s = 0
    for _ in 0..<n {
        let data = try? String(contentsOfFile: path)
        s = data?.count ?? 0
    }
    return s
}
