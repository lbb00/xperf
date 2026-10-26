def good(path, n):
    with open(path) as handle:
        data = handle.read()
    total = 0
    for _ in range(n):
        total = len(data)
    return total
