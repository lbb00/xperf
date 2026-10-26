func castLoop(_ xs: [Any]) -> [Int] {
    var out: [Int] = []
    out.reserveCapacity(xs.count)
    for x in xs {
        out.append(x as! Int)
    }
    return out
}
