func join(_ parts: [String]) -> String {
    var s = ""
    s.reserveCapacity(64)
    for p in parts {
        s.append(p)
    }
    return s
}
