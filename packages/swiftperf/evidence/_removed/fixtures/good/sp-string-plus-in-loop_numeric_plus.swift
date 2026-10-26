func sum(_ xs: [Int]) -> Int {
    var total = 0
    var depth = 0
    for x in xs {
        total += x
        depth += 1
    }
    return total + depth
}

func tally(_ xs: [Int]) -> Int {
    var nerr = 0
    var nhint = 0
    for x in xs {
        if x < 0 { nerr += 1 } else { nhint += 1 }
    }
    return nerr + nhint
}
