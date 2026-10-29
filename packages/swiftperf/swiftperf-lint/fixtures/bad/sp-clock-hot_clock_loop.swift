func bad(n: Int) -> Int {
    var s = 0
    for i in 0..<n {
        s ^= Int(Date().timeIntervalSince1970 * 1_000_000) ^ i
    }
    return s
}
