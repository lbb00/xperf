func encode(_ pairs: [(String, String)]) -> String {
    pairs.reduce(into: "") { acc, p in
        if !acc.isEmpty { acc += "&" }
        acc += "\(p.0)=\(p.1)"
    }
}
