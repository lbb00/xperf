func good(n: Int) async -> Int {
    var s = 0
    for i in 0..<n {
        s ^= Int(Date().timeIntervalSince1970)
        await Task.yield()
        s ^= i
    }
    return s
}
