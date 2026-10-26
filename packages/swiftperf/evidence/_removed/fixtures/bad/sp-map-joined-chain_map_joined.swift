func encode(_ pairs: [(String, String)]) -> String {
    return pairs.map { "\($0)=\($1)" }.joined(separator: "&")
}

func encode2(_ pairs: [(String, String)]) -> String {
    return pairs
        .map { "\($0)=\($1)" }
        .joined(separator: "&")
}
