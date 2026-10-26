func labels(_ items: [String?]) -> [String] {
    var out: [String] = []
    for item in items {
        out.append(item!)
    }
    return out
}
