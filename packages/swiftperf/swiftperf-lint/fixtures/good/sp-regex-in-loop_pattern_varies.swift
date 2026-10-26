func good(_ lines: [String]) -> Int {
    var n = 0
    for line in lines {
        let re = try NSRegularExpression(pattern: line)
        let range = NSRange(location: 0, length: line.utf16.count)
        if re.numberOfMatches(in: line, options: [], range: range) > 0 {
            n += 1
        }
    }
    return n
}
