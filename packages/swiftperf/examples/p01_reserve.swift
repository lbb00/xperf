func join(_ parts: [String]) -> String {
    var s = ""
    s.reserveCapacity(parts.reduce(0) { $0 + $1.count })
    for p in parts {
        s.append(p)
    }
    return s
}
