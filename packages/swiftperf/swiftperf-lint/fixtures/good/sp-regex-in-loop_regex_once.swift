func digits(_ lines: [String]) -> [String] {
    let re = try NSRegularExpression(pattern: "[0-9]+")
    var hits: [String] = []
    hits.reserveCapacity(lines.count)
    for line in lines {
        let range = NSRange(location: 0, length: line.utf16.count)
        if re.firstMatch(in: line, options: [], range: range) != nil {
            hits.append(line)
        }
    }
    return hits
}

func swiftRegex(_ lines: [String]) -> [String] {
    var hits: [String] = []
    hits.reserveCapacity(lines.count)
    for line in lines {
        let re = Regex("[0-9]+")
        if line.contains(re) {
            hits.append(line)
        }
    }
    return hits
}
