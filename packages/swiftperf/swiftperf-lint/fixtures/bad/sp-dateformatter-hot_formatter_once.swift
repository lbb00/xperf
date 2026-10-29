func formatAll(_ dates: [Date]) -> [String] {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    var out: [String] = []
    out.reserveCapacity(dates.count)
    for date in dates {
        out.append(fmt.string(from: date))
    }
    return out
}
