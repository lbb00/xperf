def bad(path, n):
    total = 0
    for _ in range(n):
        with open(path) as handle:
            total = len(handle.read())
    return total
