func labels(_ items: [String?]) -> [String] {
    var out: [String] = []
    out.reserveCapacity(items.count)
    for item in items {
        guard let s = item else { continue }
        out.append(s)
    }
    return out
}
