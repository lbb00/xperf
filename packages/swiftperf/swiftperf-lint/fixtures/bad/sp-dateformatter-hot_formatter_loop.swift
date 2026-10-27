func formatAll(_ dates: [Date]) -> [String] {
    var out: [String] = []
    out.reserveCapacity(dates.count)
    for date in dates {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        out.append(fmt.string(from: date))
    }
    return out
}
