func good(n: Int) -> Int {
    let t = Int(Date().timeIntervalSince1970 * 1_000_000)
    var s = 0
    for i in 0..<n {
        s ^= t ^ i
    }
    return s
}
